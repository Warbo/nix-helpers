{ die, dummyBuild, getType, isAttrSet, lexCompare, lib }:

with builtins;
with lib;
with rec {
  srt = sort (x: y: lexCompare x y == -1);

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
