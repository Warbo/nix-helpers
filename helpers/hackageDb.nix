{ cabal-install2, hackageTimestamp, runCommand }:

runCommand "get-hackagedb"
  {
    cacheBuster = builtins.toString hackageTimestamp;
    buildInputs = [ cabal-install2 ];
  }
  ''
    mkdir "$out"
    HOME="$out" cabal update
  ''
