{ haskellPackages, runCabal2nix }:

name: haskellPackages.callPackage (runCabal2nix {
                                    inherit name;
                                    url = "cabal://${name}";
                                  }) {}
