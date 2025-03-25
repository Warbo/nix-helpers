# We keep the fetchGitIPFS.nix file seaparate, since it's useful to fetch on its
# own from IPFS.
{ nixpkgs }:
(import ./fetchGitIPFS.nix {
  pkgs = nixpkgs;
}).fetchGitIPFS
