# Returns nix-helpers from the latest entry in ./nixpkgs.nix
with rec {
  # Some arbitrary nixpkgs repo, so we can use its 'lib'
  bootstrap = import (import ./nix/sources.nix).repo1909 {
    config   = {};
    overlays = [];
  };

  nixpkgs = import ./nixpkgs.nix { inherit (bootstrap) lib; };
};
(import nixpkgs.repoLatest {
  config   = {};
  overlays = [ (import ./overlay.nix) ];
}).nix-helpers
