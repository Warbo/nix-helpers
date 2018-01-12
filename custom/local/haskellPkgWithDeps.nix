{ cabalField, callPackage, haskell, haskellPkgDeps, lib, pkgs, reverse,
  runCabal2nix, runCommand, stableHackageDb, withDeps }:

{
  delay-failure   ? false,  # Replace eval-time failures with failing derivation
  dir,
  extra-sources   ? [],
  name            ? null,
  hackageContents ? stableHackageDb,
  hsPkgs
}:

with builtins;
with lib;
with rec {
  deps = haskellPkgDeps {
    inherit delay-failure dir extra-sources hackageContents;
    inherit (hsPkgs) ghc;
    name = pName;
  };

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

  nameOf = pkg: if hasPrefix "cabal://" pkg
                   then pkgName pkg
                   else cabalField { dir = pkg; field = "name"; };

  # Run cabal2nix on each dependency
  funcs = listToAttrs (map (url: rec {
                             name  = nameOf url;
                             value = runCabal2nix { inherit name url; };
                           })
                           deps);

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
              thisName = nameOf pkg;
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
                 mapAttrs (_: _: null) funcs)
                deps;

  # The desired package, including tests
  fullPkg = callPackageWith (pkgs // untested) (getAttr pName funcs) {};
};

if deps.delayedFailure or false
   then runCommand "failed-${pName}"
          {
            inherit (deps) stderr;
            msg = ''
              We failed to solve this Haskell package's dependencies. To prevent
              eval-time problems, the error was delayed to build time, in the
              form of this failing package.

              Contents of stderr follows.
            '';
          }
          ''
            set -e
            echo "$msg"    1>&2
            echo "$stderr" 1>&2
            exit 1
          ''
   else fullPkg
