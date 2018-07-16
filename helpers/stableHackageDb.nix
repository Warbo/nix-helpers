{ mkStableHackageDb }:

rec {
  def   = (mkStableHackageDb {}).installed;
  tests = {
    haveInstalled = def;
  };
}
