# Useful for release.nix files in Haskell projects
{ cabalField, collapseAttrs, composeWithArgs, die, fail, fetchgit, getType,
  haskell, haskellPkgDeps, hello, isAttrSet, isCallable, lib, nix, nothing,
  pinnedNixpkgs, repo1609, runCabal2nix2, runCommand, unpack, withDeps, withNix,
  writeScript }:

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

  dummyArgsFor = func:
    assert isCallable func || die {
      error = "Can only get args for callables";
      given = getType func;
    };
    listToAttrs (map (x: { name = x; value = x; })
                     (attrNames (functionArgs func)));

  # Calls the Haskell package defined by the given file with dummy
  # arguments, to see which arguments should come from nixpkgs and which
  # from haskellPackages (self). Uses this info to call the package
  # "properly". This is especially useful for args like 'zlib', which
  # could be from either. We also disable any benchmarks, since they can cause
  # cyclic dependencies that Nix can't handle.
  callProperly = nixpkgs: self: file:
    assert isAttrSet nixpkgs;
    assert isAttrSet self;
    with rec {
      func    = import file;

      sysArgs = func (dummyArgsFor func // {
        mkDerivation = args: args.librarySystemDepends or [];
      });

      sysPkgs = listToAttrs
        (map (name: { inherit name; value = getAttr name nixpkgs; })
        sysArgs);

      pkg = self.callPackage func sysPkgs;

      result = haskell.lib.dontBenchmark pkg;
    };
    assert isCallable func || die {
      inherit file;
      error = "File should define a callable value";
      given = getType func;
    };
    result;

  mkHackageSet =
    { dir, name, extraSources, postProcess, haskellPackages, nixpkgs }:
      assert isString  name;
      assert isAttrSet haskellPackages;
      assert isAttrSet nixpkgs;
      assert isAttrSet extraSources;
      assert isAttrSet postProcess;
      with haskellPkgDeps {
        inherit dir;
        inherit (haskellPackages) ghc;
        extra-sources = attrValues extraSources;
      };
      assert isList deps || die {
        error = "Need list of deps";
        given = getType deps;
      };
      assert isList gcRoots || die {
        error = "Expected list of gcRoots";
        given = getType gcRoots;
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
            func   = runCabal2nix2 {
              inherit name url;
              args = [ "--compiler=${haskellPackages.ghc.name}" ];
            };
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
          assert isDerivation test || test == null || die {
            inherit name url;
            error = "Expected cabal2nix result to define a package";
            given = getType test;
          };
          assert isDerivation ppTest || ppTest == null || die {
            inherit name url;
            error = "Expected postprocessed result to be package";
            given = getType ppTest;
          };
          result;

        hsPkgs = haskellPackages.override (old: {
          overrides = composeList [
            # First we apply any existing overrides on top of the defaults
            (old.overrides or (_: _: {}))

            # Next we override any packages which should be postprocessed
            (processed postProcess)

            # The next overrides add the contents of extraSources (these are
            # postprocessed, if required, thanks to using 'callPkg')
            (self: super:
              mapAttrs (name: url:
                         with {
                           # Use super for assertions to prevent infinite loop
                           test   = callPkg super super { inherit name url; };
                           result = callPkg self  super { inherit name url; };
                         };
                         assert isDerivation test || die {
                           inherit name url;
                           error = "extraSource should be derivation";
                           given = getType test;
                         };
                         result)
                       extraSources)

            # We add warnings which, if triggered, indicate that some dependency
            # wasn't "frozen" by 'deps'
            (self: super: mapAttrs
              (name: if elem name [ "callPackage" "ghc" "integer-gmp"
                                    "mkDerivation" ] ||
                        super."${name}" == null
                        then (x: x)
                        else trace
                               "Warning: Non-frozen Haskell package ${name}")
              super)

            # The final overrides add the packages (either specific versions or
            # taken from specific directories) given by 'deps'
            (self: super: listToAttrs
              (map (url:
                     with rec {
                       func = import (runCabal2nix2 { inherit url; });

                       # Beware 'with { name = ...; }' not shadowing the outer
                       # function's 'name' argument, due to quirky Nix scopes.
                       pname = (func (dummyArgsFor func // {
                         mkDerivation = args: args;
                       })).pname;

                       # Use super for assertions to prevent infinite loop
                       test  = callPkg super super {
                                 inherit url;
                                 name = pname;
                               };
                       value = callPkg self  super {
                                 inherit url;
                                 name = pname;
                               };
                     };
                     assert isString pname || die {
                       inherit url;
                       error = "Dep name should be string";
                       given = getType pname;
                     };
                     /*assert isDerivation test || die {
                       inherit name url;
                       error = "Dep should be a derivation";
                       given = getType test;
                     };*/
                     {
                       inherit value;
                       name = pname;
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

  testPackageSet = { funcName, func }:
    with rec {
      nixpkgs         = getNix "nixpkgs1803";
      haskellPackages = nixpkgs.haskell.packages.ghc802;
      hs              = func {
        inherit haskellPackages nixpkgs;
        dir          = unpack haskellPackages.digest.src;
        name         = "digest";
        extraSources = {};
        postProcess  = { integer-gmp = _: hello // { name = "sentinel"; }; };
      };
    };
    assert hs.hsPkgs.integer-gmp.name == "sentinel" || die {
      inherit funcName;
      error    = "Didn't get result from postprocessor";
      expected = "sentinel";
      found    = hs.hsPkgs.integer-gmp.name;
      drv      = hs.hsPkgs.integer-gmp;
    };
    {};

  mkHaskellSet = { dir, extraSources, haskellPackages, name, nixpkgs, postProcess }:
    with rec {
      callPkg = self: { name, url }:
        with rec {
          pp     = postProcess."${name}" or (x: x);
          func   = runCabal2nix2 { inherit name url; };
          pkg    = callProperly nixpkgs self  func;
          result = pp pkg;
        };
        assert isCallable pp || die {};
        result;

      extras = self: super: mapAttrs (name: url: callPkg self {
                                       inherit name url;
                                     })
                                     extraSources;

      given = self: super: {
        "${name}" = callPkg self { inherit name; url = dir; };
      };
    };
    {
      hsPkgs = haskellPackages.override (old: {
        overrides = composeList [
          (old.overrides or (_: _: {}))
          (processed postProcess)
          extras
        ];
      });
    };
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
      bfHkg = { haskellPackages, nixpkgs }:
        with mkHackageSet {
          inherit dir extraSources haskellPackages name nixpkgs postProcess;
        };
        withDeps gcRoots (getAttr name hsPkgs);

      bfHsk = { haskellPackages, nixpkgs }:
        with mkHaskellSet {
          inherit dir extraSources haskellPackages name nixpkgs postProcess;
        };
        getAttr name hsPkgs;

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
      hsV = "ghc802";

      nixV = "nixpkgs${
        concatStrings (take 2 (splitString "." nixpkgsVersion))
      }";

      check = {
        hackageSets ? { "${nixV}" = [ hsV ]; },
        name,
        nixpkgsSets ? { "${nixV}" = [ hsV ]; },
        postProcess ? {}
      }@args:
        with rec {
          result = def {
            inherit hackageSets name nixpkgsSets;
            dir         = unpack (haskell.packages."${hsV}"."${name}").src;
            postProcess = {
              # Use integer-gmp from nixpkgs to avoid dealing with C libraries
              integer-gmp = _:
                trace ("Taking integer-gmp from ${nixV} " +
                       "${hsV} to avoid missing C library dependencies.")
                      (getNix nixV).haskell.packages."${hsV}".integer-gmp;
            } // postProcess;
          };
          isHackage = hackageSets != {};
          isNixpkgs = nixpkgsSets != {};
          checkSet  = setName: set:
            assert attrNames set == [ nixV ] || die {
              error  = "Invalid contents";
              value  = setName;
              given  = attrNames set;
              wanted = [ nixV ];
            };
            assert attrNames (getAttr nixV set) == [ hsV ] || die {
              error  = "Invalid contents";
              value  = [ setName nixV ];
              given  = attrNames (getAttr nixV set);
              wanted = [ hsV ];
            };
            assert all (x: x)
                       (attrValues
                         (mapAttrs (path: pkg: pkg.pname == name || die {
                                     inherit name path;
                                     error = "Resulting package has wrong name";
                                     given = pkg.pname;
                                   })
                                   (collapseAttrs set)));
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

      postprocessed = depType: (check {
        name        = "digest";
        postProcess = {
          integer-gmp = _: throw "Triggered integer-gmp override";
        };
      })."${depType}"."${nixV}"."${hsV}";

      checkPostprocessed = depType:
        with rec {
          result = postprocessed depType;
          forcer = "${result}";
        };
        with tryEval forcer;
        success -> die {
          inherit depType value;
          error = "Post-processor wasn't invoked for integer-gmp";
        };
    };
    #assert checkPostprocessed "hackageDeps";
    #assert checkPostprocessed "nixpkgsDeps";
    testPackageSet { funcName = "mkHackageSet"; func = mkHackageSet; } //
    testPackageSet { funcName = "mkHaskellSet"; func = mkHaskellSet; } // {
      /*panhandle = def {
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
        postProcess =
          with { pinned = (getNix "nixpkgs1803").haskell.packages.ghc7103; };
          {
            # integer-gmp depends on C libraries, which are a pain
            integer-gmp = _: pinned.integer-gmp;

            # containers seems to be part of the bootstrap packages, so we can't
            # (or shouldn't) try to build it ourselves
            containers = _: pinned.containers;

            # deepseq seems intimately tangled with the particular Cabal library
            deepseq = _: pinned.deepseq;

            # Avoids Setup.hs problems
            stm = _: pinned.stm;

            # Dependencies of semigroups vary per GHC release, so we force an
            # override to avoid problems which seem to be related to this issue
            # https://github.com/NixOS/nixpkgs/issues/16542
            #semigroups = _: pinned.callHackage "semigroups" "0.18.2" {};
          };
      };*/

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
