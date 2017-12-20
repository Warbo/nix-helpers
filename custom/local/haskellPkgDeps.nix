{ cabal-install, haskell, jq, lib, runCommand, stableHackageDb, utillinux }:

with lib;

{
  dir,
  extra-sources   ? [],
  hackageContents ? stableHackageDb,
  name            ? "pkg"
  pkgs
}:

import (runCommand "haskell-${name}-deps.nix"
  {
    inherit dir hackageContents;
    buildInputs  = [ cabal-install jq pkgs.ghc utillinux ];
    extraSources = concatStringsSep "\n" extra-sources;
    expr         = ''
      with builtins;
      listToAttrs (map (nv: { name = elemAt nv 0; value = elemAt nv 1; })
                       (fromJSON (readFile ./versions.json)))
    '';
  }
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
  while read -r SRC
  do
    cabal sandbox add-source "$SRC"
  done < <(echo "$extraSources")

  GOT=$(cabal install --dry-run           \
                      --enable-tests      \
                      --enable-benchmarks) ||
  {
    echo "$GOT" 1>&2
    echo "Error listing cabal dependencies" 1>&2
    exit 1
  }

  MSG='the following would be installed'
  L=$(echo "$GOT" | grep -A 9999999 "$MSG" | tail -n+2 | tr -d ' ')

  function format {
    while read -r DEP
    do
      NAME=$(echo "$DEP" | rev | cut -d '-' -f2- | rev)
      echo "\"$NAME\" = runCabal2nix {
                          name = \"$NAME\";
                          url  = \"cabal://$DEP\";
                        };"
    done
  }

  echo '['                                         >  "$out"
    echo "$L" | head -n-1 | jq -R '"cabal://" + .' >> "$out"
    echo "\"$dir\""                                >> "$out"
  echo ']'                                         >> "$out"
'')
