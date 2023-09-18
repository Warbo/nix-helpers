{ nixpkgs-lib, stripOverrides }:

with {
  removeRecurseForDerivations = nixpkgs-lib.filterAttrsRecursive
    (k: _: k != "recurseForDerivations");
};
x: removeRecurseForDerivations (stripOverrides x)
