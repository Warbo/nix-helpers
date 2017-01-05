{ cabal-install, nix, runCommand }:

with builtins;

runCommand "get-hackagedb"
  {
    cacheTTL    = currentTime / (60 * 60 * 24);
    buildInputs = [ cabal-install ];
  }
  ''
    echo "$cacheTTL" > /dev/null

    export HOME="$out"
    mkdir "$out"
    cabal update
  ''
