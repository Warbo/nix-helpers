# Useful for release.nix files in Haskell projects
{ cabalField, composeWithArgs, die, fail, haskell, haskellPkgDeps, lib, nix,
  pinnedNixpkgs, repo1609, runCabal2nix, runCommand, unpack, withDeps, withNix,
  writeScript }:

with builtins;
with lib;
with rec {
  getNix = v: getAttr v pinnedNixpkgs;

  # Make the nixVersion attr (if kept) a set of all its Haskell versions
  buildForNixpkgs = hs: nixVersion: haskellVersions:
    assert isString nixVersion || die {
      error = "nixVersion should be string";
      given = typeOf nixVersion;
    };
    assert isList haskellVersions && all isString haskellVersions || die {
      error = "haskellVersions should be list of strings";
      given = typeOf haskellVersions;
      elems = if isList haskellVerisons
                 then map typeOf haskellVersions
                 else "Not a list";
    };
    assert isFunction hs || die ({
      error = "hs should be a function";
      given = typeOf hs;
    } // (if isAttrs hs then { names = attrNames hs; } else {}));
    with {
      nixpkgs = getNix nixVersion // {
        # Avoid https://github.com/haskell/zlib/issues/11
        # FIXME: Add tests to ensure that this is still needed
        zlib = (getNix nixVersion).callPackage
                 (repo1609 + "/pkgs/development/libraries/zlib") {};
      };
    };
    genAttrs haskellVersions
             (name: hs {
               inherit nixpkgs;
               haskellPackages = getAttr name nixpkgs.haskell.packages;
             });

  # Calls the Haskell package defined by the given file with dummy
  # arguments, to see which arguments should come from nixpkgs and which
  # from haskellPackages (self). Uses this info to call the package
  # "properly". This is especially useful for args like 'zlib', which
  # could be from either.
  callProperly = nixpkgs: self: file:
    assert isAttrs nixpkgs;
    assert isAttrs self;
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

  buildForHackage = { dir, name }: { haskellPackages, nixpkgs }:
    assert isString name;
    assert isAttrs haskellPackages;
    assert isAttrs nixpkgs;
    assert !isDerivation haskellPackages;
    assert !isDerivation nixpkgs;
    with rec {
      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      hackageDeps = haskellPkgDeps {
        inherit dir;
        inherit (haskellPackages) ghc;
      };

      hsPkgs = haskellPackages.override {
        overrides = self: super: mapAttrs (_: callProperly nixpkgs self)
          hackageDeps;
      };
    };
    getAttr name hsPkgs;

  buildForHaskell = { dir, name }: { haskellPackages, nixpkgs }:
    callProperly nixpkgs haskellPackages (runCabal2nix { url = dir; });
};
rec {
  def = {
    dir,               # Directory of a Haskell project
    customSets  ? {},  # Extra Haskell package sets to use (e.g. overridden)
    hackageSets ? {},  # Sets to use with Hackage dependencies
    name,              # Cabal package name
    nixpkgsSets ? {},  # Sets to use with nixpkgs dependencies
  }:
    with {
      forHackage = buildForHackage { inherit dir name; };
      forHaskell = buildForHaskell { inherit dir name; };

      isSetOf = valType: name: x:
        (!isDerivation           x &&
         isAttrs                 x &&
         all (valType (name + " value")) (attrValues x)) || die {
          error = name + " should be a set";
          given = if isDerivation x then "derivation" else typeOf x;
        };
      isListOf = elemType: name: x:
        (isList x && all (elemType (name + " element")) x) || die {
          error = name + " should be a list";
          given = typeOf x;
        };
      isASet = name: x: (!isDerivation x && isAttrs x) || die {
        error = name + " should be a set";
        given = if isDerivation x then "derivation" else typeOf x;
      };
      isAString = name: x: isString x || die {
        error = name + " should be a string";
        given = typeOf x;
      };
    };
    assert isSetOf isASet               "customSets"  customSets;
    assert isSetOf (isListOf isAString) "hackageSets" hackageSets;
    assert isSetOf (isListOf isAString) "nixpkgsSets" nixpkgsSets;
    fold mergeAttrs {} [
      (if  customSets == {} then {} else {
        customDeps  = mapAttrs                  forHaskell   customSets; })
      (if hackageSets == {} then {} else {
        hackageDeps = mapAttrs (buildForNixpkgs forHackage) hackageSets; })
      (if nixpkgsSets == {} then {} else {
        nixpkgsDeps = mapAttrs (buildForNixpkgs forHaskell) nixpkgsSets; })
    ];

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
        dir         = unpack (getPkg name).src;
        nixpkgsSets = { "${currentVersion}" = [ hsVersion ]; };
        hackageSets = { "${currentVersion}" = [ hsVersion ]; };
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
        assert elem "hackageDeps" (attrNames result) &&
               elem "nixpkgsDeps" (attrNames result) &&
               length (attrNames result) == 2        || die {
          error = "Attributes should be hackageDeps and nixpkgsDeps";
          names = attrNames result;
        };
        assert attrNames result.hackageDeps == [ stable ] || die {
          error = "hackageDeps should only contain '${stable}'";
          names = attrNames result.hackageDeps;
        };
        assert attrNames result.nixpkgsDeps == [ stable ] || die {
          error = "nixpkgsDeps should only contain '${stable}'";
          names = attrNames result.nixpkgsDeps;
        };
        assert attrNames result.hackageDeps."${stable}" == [hsVersion] || die {
          error = "hackageDeps.${stable} should only contain '${hsVersion}'";
          names = attrNames result.hackageDeps."${stable}";
        };
        result;
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
