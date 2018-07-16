{ cabal-install, hackageTimestamp, runCommand }:

{
  def = runCommand "get-hackagedb"
    {
      cacheBuster = builtins.toString hackageTimestamp;
      buildInputs = [ cabal-install ];
    }
    ''
      mkdir "$out"
      HOME="$out" cabal update
    '';

  tests = {};
}
