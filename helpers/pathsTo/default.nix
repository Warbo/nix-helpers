{ die, dummyBuild, getType, isAttrSet, lexSort, lib }:

with rec {
  inherit (builtins) attrValues;
  inherit (lib) concatLists mapAttrs;

  go = pred: path: val:
    if isAttrSet val
       then concatLists (attrValues (mapAttrs (name: go pred (path ++ [ name ]))
                                              val))
       else if pred val then [ path ] else [];
};
pred: val: assert isAttrSet val || die {
                     error = "pathsTo should be given an attrset";
                     given = getType val;
                   };
                   lexSort (go pred [] val)
