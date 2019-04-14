{ haskellPackages, runCabal2nix }:

with builtins;
name: trace (toJSON {
        inherit name;
        warning  = "deprecated";
        function = "latestCabal";
        message  = ''
          latestCabal is deprecated, since its results aren't reproducible, and
          functions like callHackage, callCabal2nix, haskellSrc2nix, etc. have
          been added to nixpkgs.
        '';
      })
      haskellPackages.callPackage (runCabal2nix {
                                    inherit name;
                                    url = "cabal://${name}";
                                  }) {}
