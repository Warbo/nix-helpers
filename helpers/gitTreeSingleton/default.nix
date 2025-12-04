# Creates a git tree object, representing a directory containing a single entry:
# a subdirectory with the given name and SHA1.
_:
{ name, sha1 }:

with rec {
  inherit (builtins)
    concatStringsSep
    convertHash
    div
    toFile
    genList
    getAttr
    map
    stringLength
    substring
    toString
    ;
  rem = a: b: if a < b then a else rem (a - b) b;

  # Convert hex SHA1 string to binary bytes
  hexToBin =
    hex:
    with rec {
      hexPairs = genList (i: substring (i * 2) 2 hex) (div (stringLength hex) 2);
      hexToDec =
        c:
        getAttr c {
          "0" = 0;
          "1" = 1;
          "2" = 2;
          "3" = 3;
          "4" = 4;
          "5" = 5;
          "6" = 6;
          "7" = 7;
          "8" = 8;
          "9" = 9;
          "a" = 10;
          "b" = 11;
          "c" = 12;
          "d" = 13;
          "e" = 14;
          "f" = 15;
        };
      pairToByte =
        pair:
        with {
          high = hexToDec (substring 0 1 pair);
          low = hexToDec (substring 1 1 pair);
        };
        high * 16 + low;
    };
    map pairToByte hexPairs;

  sha1Bytes = hexToBin (convertHash {
    hash = sha1;
    hashAlgo = "sha1";
    toHashFormat = "base16";
  });
  mode = "40000"; # For a subdirectory (tree), mode is "40000"

  # mode (5) + space (1) + name length + null (1) + sha1 (20)
  entryLen = 5 + 1 + (stringLength name) + 1 + 20;

  # Convert byte to octal for printf
  byteToOctal =
    byte:
    with rec {
      d1 = div byte 64;
      r1 = rem byte 64;
      d2 = div r1 8;
      d3 = rem r1 8;
    };
    "${toString d1}${toString d2}${toString d3}";

  builder = toFile "builder.sh" ''
    printf 'tree %s\000' "${toString entryLen}" > "$out"

    # Write mode and space
    printf '%s' "${mode} " >> "$out"

    # Write name
    printf '%s' "${name}" >> "$out"

    # Write null byte after name
    printf '\000' >> "$out"

    # Write SHA1 as binary bytes
    ${concatStringsSep "\n    " (
      map (byte: "printf '\\${byteToOctal byte}' >> \"$out\"") sha1Bytes
    )}
  '';

};
derivation {
  name = "git-tree-${name}";
  system = builtins.currentSystem;
  builder = "/bin/sh";
  args = [ builder ];
}
