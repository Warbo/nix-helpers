# Removes null values from a list or attrset
{ lib }:
with {
  inherit (builtins) concatMap isAttrs isList;
};
xs: if isList xs
    then concatMap (x: if x == null then [] else [x]) xs
    else if isAttrs xs
    then lib.filterAttrs (_: value: value != null) xs
    else abort "catNull needs a list or attrset"
