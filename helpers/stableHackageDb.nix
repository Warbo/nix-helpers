{ mkStableHackageDb }:

rec {
  def   = (mkStableHackageDb {}).installed;
  tests = def;
}
