{ hasBinary, withDeps }:

{
  def   = bin: pkg: withDeps [ (hasBinary pkg bin) ] pkg;
  tests = {};
}
