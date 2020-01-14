# IOHK's haskell.nix infrastructure
{ repo1909 }:

with {
  src = builtins.fetchTarball {
    name   = "haskell-nix";
    url    = https://github.com/Warbo/haskell.nix/archive/499a761.tar.gz;
    sha256 = "1pnkywswfa71hgc2c3g2cijfk9nysbpyh6jjh455h810n4yhs522";
  };
};
{
  def   = { repo ? repo1909 }: import repo {
            overlays = import "${src}/overlays";
          };
  tests = {};
}
