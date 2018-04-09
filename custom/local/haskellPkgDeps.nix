{ cabal-install, cabalField, dropWhile, fail, haskell, jq, lib,
  nixListToBashArray, nixpkgs1703, reverse, runCommand, stableHackageDb,
  stringAsList, utillinux, writeScript }:

with lib;

{
  delay-failure   ? false,  # Replace eval-time failures with failing derivation
  dir,
  extra-sources   ? [],
  hackageContents ? stableHackageDb,
  name            ? "pkg",
  ghc
}:

with rec {
  inherit (nixListToBashArray { name = "extraSources"; args = extra-sources; })
          env code;

  deps = import (runCommand "haskell-${name}-deps"
    (env // {
      inherit dir hackageContents;
      buildInputs  = [ nixpkgs1703.cabal-install fail ghc jq utillinux ];
      delayFailure = if delay-failure then "true" else "false";
      failFile     = writeScript "delayed-failure.nix" ''
        with builtins;
        {
          delayedFailure = true;
          stderr         = readFile ./ERR;
        }
      '';
    })
    ''
      set -e
      set -o pipefail

      cp -r "$dir" ./src
      chmod +w -R  ./src

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

      # The --reorder-goals option enables heuristics which make cabal more
      # likely to succeed. It's off by default since it's slower.
      GOT=$(cabal install --dry-run           \
                          --reorder-goals     \
                          --enable-tests      \
                          --enable-benchmarks 2> >(tee ERR)) || {
        if "$delayFailure"
        then
          mkdir "$out"
          cp ERR "$out/ERR"
          cp "$failFile" "$out/default.nix"
          exit 0
        else
          echo "$GOT" 1>&2
          echo "Error listing cabal dependencies" 1>&2
          exit 1
        fi
      }

      MSG='the following would be installed'
      L=$(echo "$GOT" | grep -A 9999999 "$MSG" | tail -n+2 | tr -d ' ' |
          cut -d '(' -f1)

      mkdir "$out"
      echo '['                            >  "$out/default.nix"
        echo "$L" | head -n-1 | jq -R '.' >> "$out/default.nix"
      echo ']'                            >> "$out/default.nix"
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
if deps.delayedFailure or false
   then deps
   else replacedDeps ++ [ dir ]
