# Useful for release.nix files in Haskell projects
{ cabalField, customised, fail, haskellPkgDepsDrv, lib, nix, runCabal2nix,
  runCommand, self, stableVersion, unpack, withDeps, withNix, writeScript }:

with builtins;
with lib;
with rec {
  getNix = v: getAttr v (self // { inherit (customised) unstable; });

  # Make the nixVersion attr (if kept) a set of all its Haskell versions
  buildForNixpkgs = keep: hs: nixVersion: if !(keep nixVersion) then "" else ''
    #
      "${nixVersion}" = with ${nixVersion}.haskell; {
        ${concatStringsSep "\n"
            (map hs (attrNames (getNix nixVersion).haskell.packages))}
      };
    '';

  # Make the hsVersion attr (if kept) a set with nixpkgs and hackage builds
  buildForHaskell = keep: hsVersion: if !(keep hsVersion) then "" else ''
    #
      "${hsVersion}" = go { haskellPackages = packages."${hsVersion}"; };
  '';

  # Defines nixpkgs and hackageb uilds, using a given haskellPackages set
  pkgExpr = { cabal-args ? null, dir, name }: runCommand "${name}-expr"
    {
      # Bare function, which we'll give arguments from the nixpkgs Haskell set
      nixpkgsDeps = runCabal2nix { url = dir; };

      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      hackageDeps = haskellPkgDepsDrv ((if cabal-args == null
                                           then {}
                                           else { inherit cabal-args; }) // {
                                        inherit dir;
                                      });

      default = writeScript "${name}-default.nix" ''
        { haskellPackages }:

        with builtins;
        with (import <nixpkgs> { config = {}; }).lib;
        with rec {
          depNames = import ./deps;

          overrides = self: super: genAttrs depNames
            (n: self.callPackage (./deps/pkgs + "/${"$" + "{n}"}.nix") {});

          hsPkgs = haskellPackages.override { inherit overrides; };
        };
        {
          hackageDeps = hsPkgs.${name};
          nixpkgsDeps = haskellPackages.callPackage ./fromCabal2nix.nix {};
        }
      '';
    }
    ''
      mkdir "$out"
      cp -r "$hackageDeps" "$out/deps"
      cp    "$nixpkgsDeps" "$out/fromCabal2nix.nix"
      cp "$default" "$out/default.nix"
    '';

  go = {
    cabal-args  ? null,       # Extra args for 'cabal install'
    dir,                      # Directory of a Haskell project
    name        ? null,       # Taken from .cabal file if not given
    haskellKeep ? (x: true),  # Predicate for which Haskell/GHC versions to use
    nixKeep     ? (x: true)   # Predicate for which nixpkgs versions to use
  }:
    with {
      pName = if name == null
                 then cabalField { inherit dir; field = "name"; }
                 else name;
    };
    # FIXME: This should use <nix-config> and <nixpkgs> if available. We could
    # still use ../.. to access a helper function to make that easier.
    # Defines builds for (kept) Haskell versions for (kept) nixpkgs versions
    writeScript "${pName}-release.nix" ''
      with import ${../..} {};
      with {
        go = import ${pkgExpr {
                      inherit cabal-args dir;
                      name = pName;
                    }};
      };
      {
        ${concatStringsSep "\n"
            (map (buildForNixpkgs nixKeep (buildForHaskell haskellKeep))
                 (attrNames customised))}
      }
    '';

  test =
    with rec {
      name      = "text";
      hsVersion = "ghc802";
      pkg       = attrByPath
                    [ stableVersion "haskell" "packages" hsVersion name ]
                    (abort "Missing package")
                    self;
      result    = go {
        inherit name;
        cabal-args  = [];  # Avoid tests, to prevent cycles
        dir         = unpack pkg.src;
        haskellKeep = v: v == hsVersion;
        nixKeep     = v: v == stableVersion;
      };
    };
    runCommand "check-haskellRelease"
      (withNix {
        inherit hsVersion stableVersion result;
        buildInputs = [ fail nix ];
      })
      ''
        function check {
          nix-instantiate --eval --read-write-mode \
            -E "with builtins; with { lhs = $1; rhs = $2; };"'
                assert lhs == rhs || trace (toJSON { inherit lhs rhs; }) false;
                true'
        }

        check "typeOf (import $result)" '"set"' ||
          fail "Generated release.nix doen't define a set"

        check "attrNames (import $result)" "[ \"$stableVersion\" ]" ||
          fail "Should have one attribute, with stable name '$stableVersion'"

        check "attrNames (import $result).$stableVersion" "[\"$hsVersion\"]" ||
          fail "Set should have one GHC version, namely '$hsVersion'"

        # TODO: Check that the hackage and nixpkgs attrs are set
        # TODO: Run nix-build on the actual packages

        mkdir "$out"
      '';
};
args: withDeps [ test ] (go args)
