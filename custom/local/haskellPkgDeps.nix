{ cabal-install, cabalField, dropWhile, fail, haskell, jq, lib,
  nixListToBashArray, reverse, runCommand, stableHackageDb, stringAsList,
  utillinux }:

with lib;

{
  dir,
  extra-sources   ? [],
  hackageContents ? stableHackageDb,
  name            ? "pkg",
  ghc
}:

with rec {
  inherit (nixListToBashArray { name = "extraSources"; args = extra-sources; })
          env code;

  deps = import (runCommand "haskell-${name}-deps.nix"
    (env // {
      inherit dir hackageContents;
      buildInputs  = [ cabal-install fail ghc jq utillinux ];
    })
    ''
      set -e
      set -o pipefail

      cp -r "$dir" ./src
      chmod +w -R ./src

      export HOME="$PWD/cache"
      mkdir -p "$HOME"/.cabal/packages/hackage.haskell.org
      ln -s "$hackageContents"/.cabal/packages/hackage.haskell.org/00-index.tar \
                       "$HOME"/.cabal/packages/hackage.haskell.org/

      cd ./src
      cabal sandbox init

      ${code}
      for VAL in "''${extraSources[@]}"
      do
        cabal sandbox add-source --snapshot "$VAL"
      done

      GOT=$(cabal install --dry-run           \
                          --enable-tests      \
                          --enable-benchmarks) || {
        echo "$GOT" 1>&2
        echo "Error listing cabal dependencies" 1>&2
        exit 1
      }

      MSG='the following would be installed'
      L=$(echo "$GOT" | grep -A 9999999 "$MSG" | tail -n+2 | tr -d ' ' |
          cut -d '(' -f1)

      echo '['                            >  "$out"
        echo "$L" | head -n-1 | jq -R '.' >> "$out"
      echo ']'                            >> "$out"
    '');

  extrasMap = listToAttrs (map (dir: {
                                 name = cabalField {
                                   inherit dir;
                                   field = "name";
                                 };
                                 value = dir;
                               })
                               extra-sources);

  # Takes 'foo-bar-1.2.3' and returns 'foo-bar'
  removeVersion = stringAsList
                    (chars: reverse                             # Restore order
                              (tail                             # Drop '-'
                                (dropWhile (c: c != "-")        # Drop up to '-'
                                           (reverse chars))));  # Start at end

  # If a dependency comes from extra-sources, use its path; otherwise prefix
  # with "cabal://" so cabal2nix will fetch from Hackage.
  replacedDeps = map (dep: if hasAttr (removeVersion dep) extrasMap
                              then getAttr (removeVersion dep) extrasMap
                              else "cabal://${dep}")
                     deps;
};
replacedDeps ++ [ dir ]
