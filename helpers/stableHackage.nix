{ hasBinary, mkStableHackageDb, withDeps }:

with rec {
  pkg = (mkStableHackageDb {}).installer;

  tested = withDeps [ (hasBinary pkg "makeCabalConfig") ] pkg;
};
{
  def   = tested;
  tests = tested;
}
