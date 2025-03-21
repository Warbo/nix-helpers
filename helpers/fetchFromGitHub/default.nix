# Useful in places where nixpkgs.fetchFromGitHub would cause an infinite loop.
# Calling this fetchFromGitHub makes it work with update-nix-fetchgit.
{}:
{
  owner,
  repo,
  rev,
  sha256,
}:
builtins.fetchTarball {
  inherit sha256;
  url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
}
