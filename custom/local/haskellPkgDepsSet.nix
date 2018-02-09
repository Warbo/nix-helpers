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
};

if deps.delayedFailure or false
   then deps
   else hsPkgs.override {
     overrides = self: super:
       mapAttrs (_: p: haskell.lib.dontCheck (self.callPackage p {})) funcs //
       (if funcs ? zlib
           then { zlib = self.callPackage funcs.zlib { inherit (pkgs) zlib; }; }
           else {});
   }
