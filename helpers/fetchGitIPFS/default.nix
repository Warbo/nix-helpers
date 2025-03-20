# We keep the fetchGitIPFS.nix file seaparate, since it's useful to fetch on its
# own from IPFS.
{ pkgs }:
(import ./fetchGitIPFS.nix {
  pkgs = pkgs;
}).fetchGitIPFS
