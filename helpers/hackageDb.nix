{ cabal-install, hackageTimestamp, runCommand }:

runCommand "get-hackagedb"
  {
    cacheBuster = builtins.toString hackageTimestamp;
    buildInputs = [ cabal-install ];
  }
  ''
    mkdir "$out"
    HOME="$out" cabal update
  ''
