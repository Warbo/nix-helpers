{ die, fetchGitIPFS, nixpkgs }:
with { inherit (fetchGitIPFS {}) pkgs; };
assert pkgs.path == nixpkgs.path || die {
  pkgs.path = pkgs.path;
  nixpkgs.path = nixpkgs.path;
};
{}
