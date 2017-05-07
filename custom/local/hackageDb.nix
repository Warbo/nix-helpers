{ cabal-install, nix, runCommand }:

with builtins;

runCommand "get-hackagedb"
  {
    cacheTTL    = currentTime / (60 * 60 * 24);
    buildInputs = [ cabal-install ];
  }
  ''
    echo "$cacheTTL" > /dev/null
    mkdir "$out"
    HOME="$out" cabal update
  ''
