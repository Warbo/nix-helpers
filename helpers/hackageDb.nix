{ cabal-install, hackageTimestamp, lib, runCommand }:

with {
  go = { hackageTimestamp }: runCommand "get-hackagedb"
    {
      cacheBuster = builtins.toString hackageTimestamp;
      buildInputs = [ cabal-install ];
    }
    ''
      mkdir "$out"
      HOME="$out" cabal update
    '';
};
{
  def   = lib.makeOverridable go { inherit hackageTimestamp; };
  tests = {};
}
