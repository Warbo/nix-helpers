# IOHK's haskell.nix infrastructure
{ repo1909 }:

with {
  src = builtins.fetchTarball {
    name   = "haskell-nix";
    url    = https://github.com/Warbo/haskell.nix/archive/7f7901d.tar.gz;
    sha256 = "1271g9yf77x430jdiy85v43qa8n9n6w0jlprsrv9l6kwv0qs7iv4";
  };
};
{
  def   = { repo ? repo1909 }: import repo {
            overlays = import "${src}/overlays";
          };
  tests = {};
}
