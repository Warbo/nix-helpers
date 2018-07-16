{ hasBinary, mkStableHackageDb, withDeps }:

with rec {
  pkg = (mkStableHackageDb {}).installer;

  haveBin = hasBinary pkg "makeCabalConfig";
};
{
  def   = withDeps [ haveBin ] pkg;
  tests = { inherit haveBin; };
}
