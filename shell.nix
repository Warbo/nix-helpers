with { inherit (import ./.) nixpkgsLatest pinnedNiv; };
nixpkgsLatest.stdenv.mkDerivation {
  name = "nix-helpers-env";
  buildInputs = [ pinnedNiv ];
}
