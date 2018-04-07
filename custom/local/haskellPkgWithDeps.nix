{ cabalField, callPackage, haskell, haskellPkgDepsSet, lib, pkgs, reverse,
  runCommand, stableHackageDb, withDeps }:

{
  delay-failure   ? false,  # Replace eval-time failures with failing derivation
  dir,
  extra-sources   ? [],
  name            ? null,
  hackageContents ? stableHackageDb,
  hsPkgs,
  useOldZlib ? false
}:

with builtins;
with lib;
with rec {
  deps = haskellPkgDepsSet {
    inherit delay-failure dir extra-sources hackageContents hsPkgs useOldZlib;
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

  init      = xs: if xs == []
                     then xs
                     else reverse (tail (reverse xs));

  nameOf = pkg: if hasPrefix "cabal://" pkg
                   then pkgName pkg
                   else cabalField { dir = pkg; field = "name"; };

  # The desired package, including tests
  fullPkg = haskell.lib.doCheck (getAttr pName deps);
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
