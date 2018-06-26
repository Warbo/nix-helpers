{ mkStableHackageDb, nothing }:

with builtins;
rec {
  def   = (mkStableHackageDb {}).available;
  tests = assert typeOf def == "list"; nothing;
}
