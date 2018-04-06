{ buildEnv, curl, fail, fetchFromGitHub, gzip, jq, mkBin, nixpkgs1709, python,
  runCmd, stdenv, withDeps, writeScript }:

{
  # Git revision for all-cabal-files repo
  rev    ? "856d840",

  # Hash for all-cabal-files revision
  sha256 ? "1b0kgfncc5gh50k3pj1mk7cqpj9mdw67iqwxpkvy6r9dl0xwin61",

  # How many bytes to fetch of 01-index.tar.gz (find using 'wget --spider')
  size   ? 68265585
}:

with builtins;
with rec {
  all-cabal-files = fetchFromGitHub {
    inherit rev sha256;
    owner  = "commercialhaskell";
    repo   = "all-cabal-files";
  };

  # 00-index.tar, used by Cabal to check versions, dependencies, etc. This takes
  # a while to build, so we keep it in a standalone derivation to reduce the
  # chance that it'll need to be rebuilt (e.g. due to a dodgy test)
  archive = stdenv.mkDerivation {
    name = "hackage-00-index.tar";
    src  = all-cabal-files;

    unpackPhase = "true";  # Without this, src will be copied, which takes ages
    buildPhase  = ''
      BASE="$PWD"

      tar cf 00-index.tar -T /dev/null

      echo "Adding package dirs to 00-index.tar" 1>&2
      pushd "$src"
        for F in *
        do
          echo "Adding $F" 1>&2
          tar rf "$BASE/00-index.tar" "$F"
        done
      popd
    '';

    installPhase = ''
      cp -r 00-index.tar "$out"
    '';
  };

  index01 = runCmd "01-index.tar.gz"
    {
      SSL_CERT_FILE = /etc/ssl/certs/ca-bundle.crt;
      buildInputs   = [ curl gzip ];
      size          = toString (size - 1);  # Since it's 0 indexed
      url           = https://hackage.haskell.org/01-index.tar.gz;
    }
    ''
      # Downloading this index from hackage is really finicky, so we do a whole
      # bunch of retries to try and make it work
      FINISHED=0
      for retry in $(seq 1 20)
      do
        # We can't use -C - to resume, since the Hackage server doesn't support
        # resuming downloads (yet they serve incremental tarballs??!)
        # -OJ writes to a file named from the URL, or header if given
        # -r 0-N will stop after N bytes
        curl -OJ -r 0-"$size" "$url" > "$out"|| continue
        FINISHED=1
        break
      done
      [[ "$FINISHED" -eq 1 ]] || exit 1
    '';

  # Command to install repo cache into ~/.cabal
  cmd = mkBin {
    name   = "makeCabalConfig";
    paths  = [ fail ];
    vars   = { inherit archive index01; };
    script = ''
      #!/usr/bin/env bash
      [[ -e "$HOME" ]] || fail "makeCabalConfig needs a HOME to put config into"

      DIR="$HOME/.cabal/packages/hackage.haskell.org"
      mkdir -p "$DIR"

      TARGET=$(readlink -f "$archive")
      cp "$TARGET" "$DIR/00-index.tar"

      INDEX=$(readlink -f "$index01")
      gunzip < "$INDEX" > "$DIR/01-index.tar"
    '';
  };

  test = runCmd "test-stablehackage"
    {
      buildInputs = [ cmd nixpkgs1709.cabal-install nixpkgs1709.ghc ];
    }
    ''
      set -e
      echo "Making config" 1>&2
      export HOME="$PWD"
      makeCabalConfig

      echo "Testing non-sandboxed install" 1>&2
      cabal install list-extras

      echo "Testing install into a sandbox" 1>&2
      cabal sandbox init
      cabal install list-extras

      echo "Testing new-*" 1>&2
      mkdir pkg
      pushd pkg
        cabal get text
        cabal new-configure
        cabal new-build
      popd

      echo pass > "$out"
    '';
};

rec {
  inherit archive;

  installer = withDeps [ test ] cmd;

  installed = runCmd "stable-hackage-db" { buildInputs = [ installer ]; } ''
    mkdir -p "$out"
    HOME="$out" makeCabalConfig
  '';

  versionsDrv = runCmd "hackage-package-versions" { inherit archive; } ''
    tar tf "$archive" | grep -o '^[^/]*/[^/]*/' |
                        sed  -e 's@/$@@g'       |
                        sed  -e 's@/@\t@g'      |
                        sort -u > "$out"
  '';

  availableDrv = runCmd "hackage-package-names" { inherit versionsDrv; } ''
    cut -f1 < "$versionsDrv" | uniq > "$out"
  '';

  versions = import (runCmd "hackage-package-versions.nix"
    {
      inherit versionsDrv;
      buildInputs = [ python ];
      script      = writeScript "version-gatherer.py" ''
        #!/usr/bin/env python
        import sys

        versions = {}

        for line in sys.stdin.readlines():
          n, v = line.split('\t')

          name    = n.strip()
          version = v.strip()

          if name in versions:
            versions[name].append(version)
          else:
            versions[name] = [ version ]

        print '{'
        for name in versions:
          print '\n"{0}" = [ {1} ];\n'.format(
              name,
              ' '.join(map(lambda x: '"{0}"'.format(x), versions[name])))
        print '}'
      '';
    }
    ''"$script" < "$versionsDrv" > "$out"'');

  available = attrNames versions;
}
