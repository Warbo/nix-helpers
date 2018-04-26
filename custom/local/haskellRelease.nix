# Useful for release.nix files in Haskell projects
{ customised, fail, haskellPkgDepsDrv, latest, lib, nix, runCabal2nix,
  runCommand, self, unpack, withDeps, withNix, writeScript }:

with builtins;
with lib;
with rec {
  # Make the nixVersion attr (if kept) a set of all its Haskell versions
  buildForNixpkgs = keep: hs: nixVersion: if !(keep nixVersion) then "" else ''
    #
      "${nixVersion}" = with ${nixVersion}.haskell; {
        ${concatStringsSep "\n"
            (map hs (attrNames (getAttr nixVersion self).haskell.packages))}
      };
    '';

  # Make the hsVersion attr (if kept) a set with nixpkgs and hackage builds
  buildForHaskell = keep: hsVersion: if !(keep hsVersion) then "" else ''
    #
      "${hsVersion}" = go { haskellPackages = packages."${hsVersion}"; };
  '';

  # Defines nixpkgs and hackageb uilds, using a given haskellPackages set
  pkgExpr = { dir, name }: runCommand "${name}-expr"
    {
      # Bare function, which we'll give arguments from the nixpkgs Haskell set
      nixpkgsDeps = runCabal2nix { url = dir; };

      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      hackageDeps = haskellPkgDepsDrv { inherit dir; };

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
    # FIXME: This should use <nix-config> and <nixpkgs> if available, rather
    # than hard-coding ../..
    # Defines builds for (kept) Haskell versions for (kept) nixpkgs versions
    writeScript "${pName}-release.nix" ''
      with import ${../..} {};
      with { go = import ${pkgExpr { inherit dir; name = pName; }}; };
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
      pkg       = self."${latest}".haskell.packages."${hsVersion}"."${name}";
      result    = go {
        inherit name;
        dir         = unpack pkg.src;
        haskellKeep = v: v == hsVersion;
        nixKeep     = v: v == latest;
      };
    };
    runCommand "check-haskellRelease"
      (withNix {
        inherit hsVersion latest result;
        buildInputs = [ fail nix ];
      })
      ''
        function check {
          nix-instantiate --eval --read-write-mode \
            -E "with builtins // { lhs = $1; rhs = $2; };"'
                assert lhs == rhs || trace (toJSON { inherit lhs rhs; }) false;
                true'
        }

        check "typeOf (import $result)" '"set"' ||
          fail "Generated release.nix doen't define a set"

        check "attrNames (import $result)" "[ \"$latest\" ]" ||
          fail "Set should have one attribute, with the latest name '$latest'"

        check "attrNames (import $result).$latest" "[ \"$hsVersion\" ]" ||
          fail "Set should have one GHC version, namely '$hsVersion'"

        # FIXME: Check that the hackage and nixpkgs attrs are set
        # FIXME: Run nix-build on the actual packages

        mkdir "$out"
      '';
};
args: withDeps [ test ] (go args)
