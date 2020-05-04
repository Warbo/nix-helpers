{ callPackage, die, dummyBuild, getType, isAttrSet, lib }:

with builtins;
with lib;
with callPackage ./util.nix {};
with rec {
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
                   srt (go pred [] val)
