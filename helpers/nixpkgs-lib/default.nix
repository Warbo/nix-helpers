# Standalone copy of Nixpkgs's "lib" attrset: smaller than depending on Nixpkgs!
with rec {
  fetchFromGitHub = args: args; # Lets us use update-nix-fetchgit

  def = fetchFromGitHub {
    owner = "nix-community";
    repo = "nixpkgs.lib";
    rev = "01fc4cd75e577ac00e7c50b7e5f16cd9b6d633e8";
    sha256 = "sha256:10l1ndysycnfwfxrhchvvjdf1lwn7kj8f89cxwzvnf5m5grfdgm4";
  };

  get =
    rev: sha256:
    fetchTarball {
      inherit sha256;
      name = "nixpkgs-lib";
      url = "https://github.com/${def.owner}/${def.repo}/archive/${rev}.tar.gz";
    };
};
{
  nixpkgs-lib-rev ? def.rev,
  nixpkgs-lib-sha256 ? def.sha256,
  nixpkgs-lib-src ? get nixpkgs-lib-rev nixpkgs-lib-sha256,
}:
import "${nixpkgs-lib-src}/lib"
