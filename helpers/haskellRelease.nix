# Useful for release.nix files in Haskell projects
{ cabalField, composeWithArgs, die, fail, fetchgit, getType, haskell,
  haskellPkgDeps, isAttrSet, lib, nix, pinnedNixpkgs, repo1609, runCabal2nix2,
  runCommand, unpack, withDeps, withNix, writeScript }:

with builtins;
with lib;
with rec {
  getNix = v: getAttr v pinnedNixpkgs;

  composeList =
    with { go = l: fold lib.composeExtensions (_: _: {}) l; };
    assert ((go [
              (_: _: { foo = false; })
              (_: _: { foo = true;  })
           ]) null null).foo || die {
      error = "composeList did not compose in order";
    };
    go;

  processed = postProcess: self: super:
    mapAttrs (name: f: assert isCallable f || die {
                         inherit name;
                         error = "postProcessor should be callable";
                       };
                       assert hasAttr name super || die {
                         inherit name;
                         error = "Don't have package to postprocess";
                       };
                       with rec {
                         old = getAttr name super;
                         new = f old;
                       };
                       assert isDerivation old || old == null || die {
                         inherit name;
                         error = "Should only postprocess packages";
                         given = getType old;
                       };
                       assert isDerivation new || new == null || die {
                         inherit name;
                         error = "Postprocessing should produce package";
                         given = getType new;
                       };
                       new)
             postProcess;

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
    } // (if isAttrSet hs then { names = attrNames hs; } else {}));
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

  dummyArgsFor = func: listToAttrs
    (map (x: { name = x; value = x; }) (attrNames (functionArgs func)));

  # Calls the Haskell package defined by the given file with dummy
  # arguments, to see which arguments should come from nixpkgs and which
  # from haskellPackages (self). Uses this info to call the package
  # "properly". This is especially useful for args like 'zlib', which
  # could be from either. We also disable any benchmarks, since they can cause
  # cyclic dependencies that Nix can't handle.
  callProperly = nixpkgs: self: file:
    assert isAttrs nixpkgs;
    assert isAttrs self;
    with rec {
      func    = import file;
      sysArgs = func (dummyArgsFor func // {
        mkDerivation = args: args.librarySystemDepends or [];
      });
      sysPkgs = listToAttrs
        (map (name: { inherit name; value = getAttr name nixpkgs; })
        sysArgs);
    };
    haskell.lib.dontBenchmark (self.callPackage func sysPkgs);

  buildForHackage = { dir, name, extraSources, postProcess }:
    { haskellPackages, nixpkgs }:
      assert isString name;
      assert isAttrs haskellPackages;
      assert isAttrs nixpkgs;
      assert isAttrSet haskellPackages;
      assert isAttrSet nixpkgs;
      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      with haskellPkgDeps {
        inherit dir;
        inherit (haskellPackages) ghc;
        extra-sources = attrValues extraSources;
      };
      with rec {
        callPkg = self: super: { name, url }:
          assert isString name || die {
            error = "Expected name to be a string";
            given = getType name;
          };
          assert isAttrSet self || die {
            error = "Expected Haskell package set (self)";
            given = getType self;
          };
          assert isAttrSet super || die {
            error = "Expected Haskell package set (super)";
            given = getType super;
          };
          with rec {
            pp     = postProcess."${name}" or (x: x);
            func   = runCabal2nix2 { inherit name url; };
            pkg    = callProperly nixpkgs self  func;
            result = pp pkg;
            # Test with super to avoid infinite loops
            test   = callProperly nixpkgs super func;
            ppTest = pp test;
          };
          assert isCallable pp || die {
            inherit name url;
            error = "Expected postprocessor to be callable";
            given = getType pp;
          };
          assert isDerivation test || die {
            inherit name url;
            error = "Expected cabal2nix result to define a package";
            given = getType test;
          };
          assert isDerivation ppTest || die {
            inherit name url;
            error = "Expected postprocessed result to be package";
            given = getType ppTest;
          };
          result;

        hsPkgs = haskellPackages.override (old: {
          overrides = composeList [
            (old.overrides or (_: _: {}))
            processed
            (self: super: mapAttrs (name: url: callPkg self { inherit name url; })
                                   extraSources)
            (self: super: listToAttrs
              (map (url:
                     with { func = import (runCabal2nix2 { inherit url; }); };
                     {
                       name  = (func (dummyArgsFor func // {
                                 mkDerivation = args: args;
                               })).pname;
                       value = callPkg self { inherit name url; };
                     })
                   deps))
          ];
        });
      };
      assert isAttrSet hsPkgs || die {
        error = "Expected Haskell packages to be set";
        given = getType hsPkgs;
      };
      assert hasAttr name hsPkgs || die {
        inherit name;
        error = "Desired package isn't in generated set";
        names = attrNames hsPkgs;
      };
      assert isDerivation hsPkgs."${name}" || die {
        inherit name;
        error = "Resulting package should be a derivation";
        given = getType hsPkgs."${name}";
      };
      assert hsPkgs."${name}".pname == name || die {
        inherit name;
        error = "Package's pname should match requested name";
        pname = hsPkgs."${name}".pname;
      };
      { inherit gcRoots hsPkgs; };

  buildForHaskell = { dir, name, extraSources, postProcess }:
    { haskellPackages, nixpkgs }:
      with rec {
        callPkg = hs: { name, url }:
          (postProcess.name or (x: x))
            (callProperly nixpkgs hs
              (runCabal2nix2 { inherit name url; }));

        processed = self: super: mapAttrs (name: f: f (getAttr name super))
                                          postProcess;

        extras    = self: super: mapAttrs (name: url: callPkg self {
                                            inherit name url;
                                          })
                                          extraSources;

        hsPkgs = if (extraSources // postProcess) == {}
                    then haskellPackages
                    else haskellPackages.override (old: {
                      overrides = composeList [
                        (old.overrides or (_: _: {}))
                        processed
                        extras
                      ];
                    });
      };
      callPkg hsPkgs { inherit name; url = dir; };
};
rec {
  def = {
    dir,                # Directory of a Haskell project
    customSets   ? {},  # Extra Haskell package sets to use (e.g. overridden)
    hackageSets  ? {},  # Sets to use with Hackage dependencies
    name,               # Cabal package name
    nixpkgsSets  ? {},  # Sets to use with nixpkgs dependencies
    extraSources ? {},  # Maps names to source dirs, e.g. if not on Hackage
    postProcess  ? {}   # Map package names to functions, e.g dontCheck
  }:
    with {
      bfHkg = buildForHackage { inherit dir name extraSources postProcess; };
      bfHsk = buildForHaskell { inherit dir name extraSources postProcess; };

      isSetOf = valType: name: x:
        (isAttrSet x &&
         all (valType (name + " value")) (attrValues x)) || die {
          error = name + " should be a set";
          given = getType x;
        };
      isListOf = elemType: name: x:
        (isList x && all (elemType (name + " element")) x) || die {
          error = name + " should be a list";
          given = typeOf x;
        };
      isASet = name: x: isAttrSet x || die {
        error = name + " should be a set";
        given = getType x;
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
        customDeps  = mapAttrs                  bfHsk   customSets; })
      (if hackageSets == {} then {} else {
        hackageDeps = mapAttrs (buildForNixpkgs bfHkg) hackageSets; })
      (if nixpkgsSets == {} then {} else {
        nixpkgsDeps = mapAttrs (buildForNixpkgs bfHsk) nixpkgsSets; })
    ];

  tests =
    # Check that this system works for some common, and some problematic,
    # Haskell packages
    with rec {
      hsVersion = "ghc802";

      getPkg    = name: attrByPath
                          [ hsVersion name ]
                          (abort "Missing package ${name}")
                          haskell.packages;

      currentVersion = "nixpkgs${
        concatStrings (take 2 (splitString "." nixpkgsVersion))
      }";

      getResult = {
        hackageSets ? { "${currentVersion}" = [ hsVersion ]; },
        name,
        nixpkgsSets ? { "${currentVersion}" = [ hsVersion ]; },
        postProcess ? {}
      }: def {
        inherit hackageSets name nixpkgsSets;
        dir         = unpack (getPkg name).src;
        postProcess = postProcess // {
          # Use integer-gmp from nixpkgs to avoid dealing with C libraries
          integer-gmp = _: (getNix "nixpkgs1803").haskellPackages.integer-gmp;
        };
      };

      check = { name, ... }@args:
        with rec {
          inherit hsVersion;
          buildInputs = [ fail nix ];
          result      = getResult args;
          stable      = currentVersion;
          isHackage   = (args.hackageDeps or null) == {};
          isNixpkgs   = (args.nixpkgsDeps or null) == {};
          checkSet    = name: set:
            assert attrNames set == [ stable ] || die {
              error  = "Invalid contents";
              value  = name;
              given  = attrNames set;
              wanted = [ stable ];
            };
            assert attrNames (getAttr stable set) == [ hsVersion ] || die {
              error  = "Invalid contents";
              value  = [ name stable ];
              given  = attrNames (getAttr stable set);
              wanted = [ hsVersion ];
            };
            true;
        };
        assert isAttrSet result || die {
          error = "Generated release doesn't define a set";
          given = getType result;
        };
        assert (isHackage -> result ? hackageDeps) &&
               (isNixpkgs -> result ? nixpkgsDeps) || die {
          inherit isHackage isNixpkgs;
          error  = "Result attributes don't match up";
          given  = attrNames result;
          wanted = (if isHackage then [ "hackageDeps" ] else []) ++
                   (if isNixpkgs then [ "nixpkgsDeps" ] else []);
        };
        assert isHackage -> checkSet "hackageDeps" result.hackageDeps;
        assert isNixpkgs -> checkSet "nixpkgsDeps" result.nixpkgsDeps;
        result;
    };
    {
      panhandle = def {
        name        = "panhandle";
        dir         = fetchgit {
          url    = http://chriswarbo.net/git/panhandle.git;
          rev    = "68db12a";
          sha256 = "1bx7xk5pcwiajih4w4rdcx568iqbpfnrzl0jqd0gcqwsnjf9kja1";
        };
        hackageSets  = { nixpkgs1803 = [ "ghc7103" ]; };
        extraSources = {
          lazysmallcheck2012 = fetchgit {
            url    = http://chriswarbo.net/git/lazy-smallcheck-2012.git;
            rev    = "dbd6fba";
            sha256 = "1i3by7mp7wqy9anzphpxfw30rmbsk73sb2vg02nf1mfpjd303jj7";
          };
        };
      };

      # A widely-used Haskell package, see if it works
      #text = check { name = "text"; };

      # zlib is awkward, since it's both a Haskell package and a system package
      zlib = check { name = "zlib"; nixpkgsSets = {}; };

      # digest also depends on the system's zlib
      digest = check { name = "digest"; };

      # This depends on the Haskell zlib package, rather than the system one
      #zlib-bindings = check { name = "zlib-bindings"; nixpkgsSets = {}; };
    };
}
