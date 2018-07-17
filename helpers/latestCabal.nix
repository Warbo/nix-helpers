{ haskellPackages, runCabal2nix }:

name: haskellPackages.callPackage (runCabal2nix { url = "cabal://${name}"; }) {}
