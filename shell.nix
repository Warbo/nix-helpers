args@{ ... }:
with {
  inherit (import ./. (removeAttrs args [ "inNixShell" ])) nixpkgs pinnedNiv;
};
nixpkgs.stdenv.mkDerivation {
  name = "nix-helpers-env";
  buildInputs = [ nixpkgs.nix-eval-jobs nixpkgs.nixfmt pinnedNiv ];
}
