self: super: import ./helpers {
  inherit (super) lib;
  callPackage   = self.newScope { inherit super; };
  pinnedNixpkgs = import ./nixpkgs.nix self super;
}
