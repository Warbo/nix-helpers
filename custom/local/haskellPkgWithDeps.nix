{ cabalField, callPackage, haskell, haskellPkgDeps, lib, pkgs, reverse,
  runCabal2nix, stableHackageDb, withDeps }:

{ dir, name ? null, hackageContents ? stableHackageDb }:

with builtins;
with lib;
with rec {
  dropUntil = pred: xs: if xs == []
                           then xs
                           else if pred (head xs)
                                   then tail xs
                                   else dropUntil pred (tail xs);

  pkgName   = s: replaceStrings [ "cabal://" ] [ "" ]
                   (concatStrings
                     (reverse
                       (dropUntil (c: c == "-")
                                  (reverse (stringToCharacters s)))));

  pName     = if name == null
                 then cabalField { inherit dir; field = "name"; }
                 else name;

  dirPkg    = runCabal2nix { name = pName; url = dir; };

  init      = xs: if xs == []
                     then xs
                     else reverse (tail (reverse xs));

  mkPkgSet  = { deps, hsPkgs }:
    with rec {
      # Run cabal2nix on each dependency
      funcs = listToAttrs (map (url: rec {
                                 name  = if url == dir
                                            then pName
                                            else pkgName url;
                                 value = runCabal2nix { inherit name url; };
                               })
                               (init deps)) // { "${pName}" = dirPkg; };

      # Instantiate a single package from the head of the 'versions' list,
      # taking dependencies from 'acc'. Insert the package into 'acc' and
      # recurse on the tail of 'versions'. This will work thanks to the order of
      # Cabal's install plan. It doesn't take dependencies of test suites or
      # benchmarks into account, so we disable them.
      go = acc: versions:
        if versions == []
           then acc
           else with rec {
                  pkg      = head versions;
                  thisName = if "${pkg}" == "${dir}"
                                then pName
                                else pkgName pkg;
                };
                go (acc // {
                     "${thisName}" = haskell.lib.dontCheck
                                       (callPackageWith (pkgs // acc)
                                                        (getAttr thisName funcs)
                                                        {});
                   })
                   (tail versions);

      # All dependencies with their tests disabled, to prevent circular deps
      untested = go (mapAttrs (n: v: if v == null || elem n [ "mkDerivation" ]
                                        then v
                                        else trace "Taking ${n} from hsPkgs" v)
                              hsPkgs //
                     mapAttrs (_: _: null)
                              funcs)
                    deps;
    };
    # The desired package, including tests
    callPackageWith (pkgs // untested) (getAttr pName funcs) {};
};
mapAttrs (n: v: mkPkgSet {
           deps   = import v;
           hsPkgs = getAttr n haskell.packages;
         })
         (haskellPkgDeps { inherit dir hackageContents; name = pName; })
