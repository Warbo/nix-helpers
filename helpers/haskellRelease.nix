# Useful for release.nix files in Haskell projects
{ cabalField, composeWithArgs, die, fail, haskell, haskellPkgDeps, lib, nix,
  pinnedNixpkgs, repo1609, runCabal2nix, runCommand, unpack, withDeps, withNix,
  writeScript }:

with builtins;
with lib;
with rec {
  getNix = v: getAttr v pinnedNixpkgs;

  # Make the nixVersion attr (if kept) a set of all its Haskell versions
  buildForNixpkgs = haskellVersions: hs: nixVersion:
    assert isString nixVersion || die {
      error = "nixVersion should be string";
      given = typeOf nixVersion;
    };
    with {
      nixpkgs = getNix nixVersion // {
        # Avoid https://github.com/haskell/zlib/issues/11
        # FIXME: Add tests to ensure that this is still needed
        zlib = (getNix nixVersion).callPackage
                 (repo1609 + "/pkgs/development/libraries/zlib") {};
      };
    };
    with nixpkgs.haskell;
    genAttrs haskellVersions
             (name: hs nixpkgs (getAttr name nixpkgs.haskell.packages));

  # Defines nixpkgs and hackagedb uilds, using a given haskellPackages set
  pkgExpr = { dir, name }: nixpkgs: haskellPackages:
    with rec {
      # Bare function, which we'll give arguments from the nixpkgs Haskell set
      nixpkgsDeps = runCabal2nix { url = dir; };

      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      hackageDeps = haskellPkgDeps {
        inherit dir;
        inherit (haskellPackages) ghc;
      };

      # Calls the Haskell package defined by the given file with dummy
      # arguments, to see which arguments should come from nixpkgs and which
      # from haskellPackages (self). Uses this info to call the package
      # "properly". This is especially useful for args like 'zlib', which
      # could be from either.
      callProperly = self: file:
        with rec {
          func    = import file;
          args    = attrNames (functionArgs func);
          dummies = listToAttrs (map (x: { name = x; value = x; }) args);
          sysArgs = func (dummies // {
            mkDerivation = args: args.librarySystemDepends or [];
          });
          sysPkgs = listToAttrs
            (map (name: { inherit name; value = getAttr name nixpkgs; })
                 sysArgs);
        };
        self.callPackage func sysPkgs;

      hsPkgs = haskellPackages.override {
        overrides = self: super: mapAttrs (_: callProperly self)
                                          hackageDeps;
      };
    };
    {
      hackageDeps = getAttr name hsPkgs;
      nixpkgsDeps = callProperly haskellPackages nixpkgsDeps;
    };
};
rec {
  def = {
    dir,                # Directory of a Haskell project
    extraSets  ? {},    # Extra Haskell package sets to use (e.g. overridden)
    haskellVersions,    # List of haskell.packages entries to use
    name,               # Cabal package name
    nixpkgsVersions     # List of nixpkgs versions to use
  }:
    assert (isList nixpkgsVersions && all isString nixpkgsVersions) || die {
      error        = "nixpkgsVersions should be a list of strings";
      actualType   = typeOf nixpkgsVersions;
      elementTypes = if isList nixpkgsVersions
                        then map typeOf nixpkgsVersions
                        else "Not a list";
    };
    assert (isList haskellVersions && all isString haskellVersions) || die {
      error        = "haskellVersions should be a list of strings";
      actualType   = typeOf haskellVersions;
      elementTypes = if isList haskellVersions
                        then map typeOf haskellVersions
                        else "Not a list";
    };
    # Defines builds for Haskell versions for nixpkgs versions, plus extras
    with { buildForHaskell = pkgExpr { inherit dir name; }; };
    genAttrs nixpkgsVersions
             (buildForNixpkgs haskellVersions buildForHaskell);

  tests =
    # Check that this system works for some common, and some problematic, Haskell
    # packages
    with rec {
      hsVersion = "ghc802";

      getPkg    = name: attrByPath
                          [ hsVersion name ]
                          (abort "Missing package ${name}")
                          haskell.packages;

      currentVersion = "nixpkgs${
        concatStrings (take 2 (splitString "." nixpkgsVersion))
      }";

      getResult = name: def {
        inherit name;
        dir             = unpack (getPkg name).src;
        haskellVersions = [      hsVersion ];
        nixpkgsVersions = [ currentVersion ];
      };

      check = name:
        with {
          inherit hsVersion;
          buildInputs = [ fail nix ];
          result      = getResult name;
          stable      = currentVersion;
        };
        assert isAttrs result || die {
          error = "Generated release doesn't define a set";
        };
        assert attrNames result == [ stable ] || die {
          error = "Should have one attribute, with stable name '${stable}'";
          names = attrNames result;
        };
        assert attrNames result."${stable}" == [ hsVersion ] || die {
          error       = "Set should have one GHC version, namely '${hsVersion}'";
          haskellSets = attrNames result."${stable}";
          resultSets  = attrNames result;
        };
        {
          inherit (result."${stable}"."${hsVersion}") hackageDeps nixpkgsDeps;
        };
    };
    {
      # A widely-used Haskell package, see if it works
      text = check "text";

      # zlib is awkward, since it's both a Haskell package and a system package
      zlib = check "zlib";

      # digest also depends on the system's zlib
      digest = check "digest";

      # This depends on the Haskell zlib package, rather than the system one
      zlib-bindings = check "zlib-bindings";
    };
}
