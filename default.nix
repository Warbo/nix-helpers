with {
  pkgs = import <nixpkgs> {
    config   = {};
    overlays = [ (import ./overlay.nix) ];
  };
};
pkgs.nix-helpers
