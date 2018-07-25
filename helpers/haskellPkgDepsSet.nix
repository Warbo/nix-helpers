{ cabalField, callPackage, haskell, haskellPkgDeps, lib, pkgs, repo1609,
  reverse, runCabal2nix, runCommand, stableHackageDb, withDeps }:

{
  dir,
  extra-sources   ? [],
  name            ? null,
  hackageContents ? stableHackageDb,
  hsPkgs,
  useOldZlib      ? false  # C zlib >= 1.2.9 may break Haskell zlib
}:

with builtins;
with lib;
with rec {
  inherit (haskellPkgDeps {
    inherit dir extra-sources hackageContents;
    inherit (hsPkgs) ghc;
    name = pName;
  }) deps gcRoots;

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

  # Run cabal2nix on each dependency
  funcs = listToAttrs (map (url: rec {
                             name  = nameOf url;
                             value = runCabal2nix { inherit name url; };
                           })
                           deps);

  # Check which arguments are system libraries (e.g. pkgs.zlib rather than
  # haskellPackages.zlib)
  findSysLibs = f:
    with rec {
      args = attrNames (functionArgs f);
      vals = genAttrs args (x: x) // {
        mkDerivation = x: x.librarySystemDepends or [];
      };
    };
    if args == {} then [] else f vals;

  callAppropriately = self: arg:
    with rec {
      f     =      if isFunction arg
                      then f
              else if isDerivation arg
                      then import arg
              else if typeOf arg == "path"
                      then import arg
                      else arg;

      zpkgs = pkgs // (if useOldZlib then { zlib = oldZlib; } else {});

      sys   = genAttrs (findSysLibs f) (n: getAttr n zpkgs);
    };
    self.callPackage f sys;

  # https://github.com/haskell/zlib/issues/11
  oldZlib = callPackage "${repo1609}/pkgs/development/libraries/zlib" {};

  allGCRoots = gcRoots ++ (attrValues funcs);

  overriddenHsPkgs = hsPkgs.override {
    overrides = self: super:
      mapAttrs (_: p: haskell.lib.dontCheck (callAppropriately self p)) funcs;
  };
};

{
  def = {
    gcRoots = allGCRoots;
    hsPkgs  = overriddenHsPkgs;
  };

  tests = {};
}
