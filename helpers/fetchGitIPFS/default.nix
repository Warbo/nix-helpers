# We keep the fetchGitIPFS.nix file separate, since it's useful to fetch on its
# own from IPFS.
{ nixpkgs }:
(import ./fetchGitIPFS.nix {
  pkgs = nixpkgs;
}).fetchGitIPFS
