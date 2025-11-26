# Remove cruft, like "override" and "overrideDerivation". These are inserted
# into attrsets automatically by functions like callPackage, but since they're
# functions, they can't be converted to strings and hence they can break things
# like build environments (which are assumed to be name/value env vars).
{ lib }:

with builtins;
with lib;
with rec {
  go = a: if isAttrs a then mapAttrs (_: go) (filterAttrs notOverride a) else a;

  notOverride =
    n: _:
    !(elem n [
      "override"
      "overrideDerivation"
    ]);
};
go
