{ nixpkgs ?
  (import ./nixpkgs.nix { lib = import helpers/nixpkgs-lib { }; }).repoLatest }:
(import nixpkgs {
  config = { };
  overlays = [ (import ./overlay.nix) ];
}).nix-helpers
