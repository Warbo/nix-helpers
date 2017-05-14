{ lib }:
with lib;
with builtins;
with {
  nixpkgs = (head (filter (p: p.prefix == "nixpkgs") nixPath)).path;
};

new: env: env // { NIX_PATH = "nixpkgs=${new}:real=${nixpkgs}"; }
