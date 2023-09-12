{ nixpkgs-lib ? import helpers/nixpkgs-lib { }
, nixpkgs ? (import ./nixpkgs.nix { inherit nixpkgs-lib; }).nixpkgsLatest }:
import ./helpers { inherit nixpkgs-lib nixpkgs; }
