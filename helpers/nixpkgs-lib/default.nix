# Standalone copy of Nixpkgs's "lib" attrset: smaller than depending on Nixpkgs!
with {
  fetchTreeFromGitHub = import ../fetchTreeFromGitHub { };
};
{
  nixpkgs-lib-tree ? "d76a7feccfaa8b36d70c98af6633375448fdb958",
  nixpkgs-lib-src ? fetchTreeFromGitHub {
    owner = "nix-community";
    repo = "nixpkgs.lib";
    tree = nixpkgs-lib-tree;
  },
}:
import "${nixpkgs-lib-src}/lib"
