with {
  owner = "NixOS";
  repo = "nixpkgs";
};
{
  fetchFromGitHub ? import ../fetchFromGitHub { },
  fetchTreeFromGitHub ? import ../fetchTreeFromGitHub { },
}:
{
  rev ? null,
  sha256 ? null,
  tree ? null,
}:
assert tree != null || rev != null;
if tree == null then
  fetchFromGitHub {
    inherit owner repo;
    ${if rev == null then null else "rev"} = rev;
    ${if sha256 == null then null else "sha256"} = sha256;
  }
else
  fetchTreeFromGitHub {
    inherit owner repo tree;
  }
