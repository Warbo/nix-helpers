# Remove cruft, like "override" and "overrideDerivation". These are inserted
# into attrsets automatically by functions like callPackage, but since they're
# functions, they can't be converted to strings and hence they can break things
# like build environments (which are assumed to be name/value env vars).
{ lib }:

with builtins;
with lib;
with rec {
  go = as: if isAttrs as
              then mapAttrs (n: go) (filterAttrs notOverride as)
              else as;

  notOverride = n: v: !(elem n ["override" "overrideDerivation"]);
};
go
