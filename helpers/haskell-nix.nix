# IOHK's haskell.nix infrastructure
{ nix-helpers-sources, repo1909 }:

{
  def = { repo ? repo1909 }: import repo {
    overlays = import "${nix-helpers-sources.haskell-nix.outPath}/overlays";
  };
  tests = {};
}
