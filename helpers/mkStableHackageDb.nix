{ buildEnv, fail, fetchFromGitHub, mkBin, nixpkgs1603, python, runCmd, stdenv,
  withDeps, wrap, writeScript }:

with builtins;
rec {
  def = {
    # Git revision for all-cabal-files repo
    rev    ? "c008e28",

    # Hash for all-cabal-files revision
    sha256 ? "0kfcc7dw6sahgkv130r144pfjsxwzq8h479fw866nf875frvpblz"
  }:

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
      name        = "hackage-00-index.tar";
      src         = all-cabal-files;
      unpackPhase = "true";  # Without this, src will be copied, which takes ages
      buildPhase  = ''
        BASE="$PWD"

        tar cf 00-index.tar -T /dev/null --format=ustar

        echo "Adding package dirs to 00-index.tar" 1>&2
        pushd "$src"
          # Add all Cabal files; use v+cut+uniq to show names of added packages
          tar rvf "$BASE/00-index.tar" * | cut -d '/' -f1 | uniq
        popd
      '';
      installPhase = ''
        cp -r 00-index.tar "$out"
      '';
    };

    # Command to install repo cache into ~/.cabal
    cmd = mkBin {
      name   = "makeCabalConfig";
      paths  = [ fail ];
      vars   = { inherit archive; };
      script = ''
        #!/usr/bin/env bash
        [[ -e "$HOME" ]] || fail "makeCabalConfig needs a HOME to put config into"

        DIR="$HOME/.cabal/packages/hackage.haskell.org"
        mkdir -p "$DIR"
        TARGET=$(readlink -f "$archive")
        cp "$TARGET" "$DIR/00-index.tar"
      '';
    };

    testScript = ''
      set -e
      echo "Making config" 1>&2
      export HOME="$PWD"
      makeCabalConfig

      echo "Testing non-sandboxed install" 1>&2
      cabal install list-extras

      echo "Testing install into a sandbox" 1>&2
      cabal sandbox init
      cabal install list-extras

      echo pass > "$out"
    '';

    cmdWithCabal = buildEnv {
      name = "cabal-with-stable-hackage";
      paths = [ cmd nixpkgs1603.cabal-install ];
    };

    test = given:
      with {
        check = runCmd "test-stablehackage"
                       { buildInputs = [ given nixpkgs1603.ghc ]; }
                       testScript;
      };
      withDeps [ check ] given;
  };
  rec {
    inherit archive;

    installer = test cmdWithCabal;

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
  };

  tests = {
    havePanhandle = runCmd "have-panhandle" { f = (def {}).versionsDrv; } ''
      grep panhandle < "$f" | grep "0.2.0.0" || {
        echo "Hackage archive doesn't contain panhandle-0.2.0.0. Found:" 1>&2
        grep panhandle < "$f" 1>&2 || echo "No versions of panhandle" 1>&2
        exit 1
      }
      mkdir "$out"
    '';
  };
}
