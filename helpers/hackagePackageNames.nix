{ dummyBuild, mkStableHackageDb }:

with builtins;
rec {
  def   = (mkStableHackageDb {}).available;
  tests = {
    haveAvailableList = assert typeOf def == "list";
                        dummyBuild "haveAvailableList";
  };
}
