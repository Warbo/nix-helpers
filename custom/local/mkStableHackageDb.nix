{ buildEnv, curl, fail, fetchFromGitHub, gzip, isBroken, jq, latest, mkBin,
  nixpkgs1603, python, runCmd, self, stdenv, withDeps, writeScript }:

{
  # Git revision for all-cabal-files repo
  rev    ? "c008e28",

  # Hash for all-cabal-files revision
  sha256 ? "0kfcc7dw6sahgkv130r144pfjsxwzq8h479fw866nf875frvpblz"
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

  cmdWithCabal =
    with rec {
      both = buildEnv {
        name = "cabal-with-stable-hackage";
        paths = [ cmd nixpkgs1603.cabal-install ];
      };

      latestStable   = getAttr latest self;

      tryLatestCabal = runCmd "try-latest-cabal"
        {
          buildInputs = [ latestStable.cabal-install cmd latestStable.ghc ];
          message     = ''
            Checking whether stableHackage works with cabal-install from latest
            nixpkgs (${latest}), i.e. whether we still need to use nixpkgs1603.
          '';
        }
        ''
          echo "$message" 1>&2
          ${testScript}
        '';
    };
    withDeps [ (isBroken tryLatestCabal) ] both;

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
}
