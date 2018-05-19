{ hasBinary, mkStableHackageDb, withDeps }:

with rec {
  pkg = (mkStableHackageDb {}).installer;

  tested = withDeps [ (hasBinary pkg "makeCabalConfig") ] pkg;
};
{
  pkg   =   tested;
  tests = [ tested ];
}
