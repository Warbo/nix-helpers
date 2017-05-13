{ cabal-install, runCommand }:

runCommand "get-hackagedb"
  {
    cacheBuster = builtins.currentTime / (60 * 60 * 24);
    buildInputs = [ cabal-install ];
  }
  ''
    mkdir "$out"
    HOME="$out" cabal update
  ''
