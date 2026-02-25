#!/usr/bin/env perl
# car2git.pl – Convert an IPFS CARv1 file to a Git packfile.
#
# Only blocks whose CID uses the git-raw codec (0x78) are kept; all others are
# silently dropped.  The CAR is read from stdin, which must be seekable (e.g. a
# regular file or process substitution) because we make two passes: the first
# counts the git-raw objects so we can write the pack header, the second streams
# their contents.  The resulting packfile is written to stdout.
#
# Deps (both in Perl core since 5.10): Compress::Zlib, Digest::SHA

use strict;
use warnings;
use Compress::Zlib qw(compress);
use Digest::SHA;

binmode STDIN,  ':raw';
binmode STDOUT, ':raw';

# ── Binary I/O helpers ────────────────────────────────────────────────────────

# Read exactly $n bytes from STDIN; die on short read or EOF.
sub slurp {
    my ($n) = @_;
    return '' if $n == 0;
    my $buf = '';
    while (length $buf < $n) {
        my $chunk;
        my $got = read STDIN, $chunk, $n - length $buf;
        die "Unexpected EOF (wanted $n, got " . length($buf) . " bytes)\n"
            unless $got;
        $buf .= $chunk;
    }
    return $buf;
}

# Read one unsigned LEB128 varint from STDIN.
# Returns undef on a clean EOF before the first byte; dies on a truncated one.
sub read_varint {
    my ($val, $shift, $first) = (0, 0, 1);
    while (1) {
        my $raw;
        my $n   = read STDIN, $raw, 1;
        return undef if $first && !$n;      # clean EOF between sections
        die "Unexpected EOF inside varint\n" unless $n;
        $first  = 0;
        my $byte = ord $raw;
        $val    |= ($byte & 0x7F) << $shift;
        $shift  += 7;
        return $val unless $byte & 0x80;    # MSB clear → last byte
    }
}

# Decode one unsigned LEB128 varint from string $data starting at $off.
# Returns (value, bytes_consumed).
sub str_varint {
    my ($data, $off) = @_;
    my ($val, $shift) = (0, 0);
    for my $i ($off .. length($data) - 1) {
        my $byte = ord substr($data, $i, 1);
        $val    |= ($byte & 0x7F) << $shift;
        $shift  += 7;
        return ($val, $i - $off + 1) unless $byte & 0x80;
    }
    die "Varint extends past end of buffer\n";
}

# ── CID parsing ───────────────────────────────────────────────────────────────
# Parse a CID at byte offset $off within string $data.
# Returns (codec, byte_length_of_cid).
#
# CIDv0 is a bare SHA2-256 multihash: 0x12 0x20 <32 bytes> (34 bytes total).
#   The codec is implied to be dag-pb (0x70).
#
# CIDv1: <version varint=1> <codec varint> <multihash>
#   multihash:  <hash-fn varint>  <digest-len varint>  <digest-len bytes>
sub parse_cid {
    my ($data, $off) = @_;

    # CIDv0: distinguished by the first two bytes being the sha2-256 multihash
    # prefix (hash code 0x12, digest length 0x20 = 32).
    if (   ord(substr $data, $off,   1) == 0x12
        && ord(substr $data, $off+1, 1) == 0x20) {
        return (0x70, 34);      # dag-pb codec; 2-byte prefix + 32-byte digest
    }

    # CIDv1
    my ($version, $vl) = str_varint($data, $off);
    die "Unsupported CID version $version\n" unless $version == 1;

    my ($codec, $cl) = str_varint($data, $off + $vl);

    # Multihash: we only need the digest length to skip past it.
    my (undef,  $fl) = str_varint($data, $off + $vl + $cl);          # hash fn
    my ($dlen,  $dl) = str_varint($data, $off + $vl + $cl + $fl);    # digest len

    return ($codec, $vl + $cl + $fl + $dl + $dlen);
}

# ── Git packfile encoding ─────────────────────────────────────────────────────
# Build the variable-length type+size header for one packfile entry.
#
# First byte:  MSB=more | type[2:0] in bits 6–4 | size[3:0] in bits 3–0
# Each further byte while MSB was set: MSB=more | next 7 size bits
#
# "size" is the byte count of the *uncompressed* object content (not including
# the loose-object "type SP size NUL" framing, which packfiles do not store).
sub obj_header {
    my ($type, $size) = @_;
    my $c    = ($type << 4) | ($size & 0xF);
    $size  >>= 4;
    my $out  = '';
    while ($size) {
        $out  .= chr($c | 0x80);
        $c     = $size & 0x7F;
        $size >>= 7;
    }
    return $out . chr($c);
}

my %GIT_TYPE = (commit => 1, tree => 2, blob => 3, tag => 4);
my $CODEC_GIT_RAW = 0x78;

# ── Main ──────────────────────────────────────────────────────────────────────

# Pass 1: count git-raw objects so we can write the pack header up front.
#    Each section: varint(len) | CID | block-bytes   (len covers CID+block).

my $hdr_len = read_varint() // die "Empty input\n";
slurp($hdr_len);                                    # skip the CARv1 header

my $obj_count = 0;
while (defined(my $sec_len = read_varint())) {
    my $sec          = slurp($sec_len);
    my ($codec, $cl) = parse_cid($sec, 0);
    $obj_count++ if $codec == $CODEC_GIT_RAW;
}

# Rewind for pass 2.
seek(STDIN, 0, 0) or die "seek failed (is stdin seekable?): $!\n";

# Pass 2: emit the packfile.  A running SHA-1 is accumulated over every byte
#    written; its digest becomes the mandatory 20-byte trailer.
my $sha = Digest::SHA->new(1);
sub emit {
    $sha->add($_[0]);
    print $_[0] or die "write failed: $!\n";
}

$hdr_len = read_varint() // die "Empty input on rewind\n";
slurp($hdr_len);                                    # skip the CARv1 header again

#   Pack header
emit('PACK');                           # 4-byte magic
emit(pack 'N', 2);                      # 4-byte version = 2 (network/big-endian)
emit(pack 'N', $obj_count);             # 4-byte object count

#   One entry per object (all undeltified)
#   git-raw block data is a complete git loose object: "<type> <size>\0<content>"
while (defined(my $sec_len = read_varint())) {
    my $sec          = slurp($sec_len);
    my ($codec, $cl) = parse_cid($sec, 0);
    next unless $codec == $CODEC_GIT_RAW;

    my $raw          = substr($sec, $cl);
    my $nul          = index($raw, "\0");
    die "No NUL byte in git object header\n" if $nul < 0;

    my ($type_str)   = substr($raw, 0, $nul) =~ /^(\S+)/;
    my $type_num     = $GIT_TYPE{$type_str}
        // die "Unknown git object type '$type_str'\n";

    my $content      = substr($raw, $nul + 1);
    emit(obj_header($type_num, length $content));               # type+size header
    emit(compress($content) // die "zlib compression failed\n");# deflated content
}

#   20-byte SHA-1 of all preceding output (not itself hashed)
print $sha->digest or die "write failed: $!\n";
