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
rec {
  def   = pred: val: assert isAttrSet val || die {
                       error = "pathsTo should be given an attrset";
                       given = getType val;
                     };
                     srt (go pred [] val);
  tests =
    with rec {
      simple    = def isString { x = 42; };
      nested    = def isString { x = { y = { z = "hello"; }; }; };
      nestWant  = [ [ "x" "y" "z" ] ];
      multi     = def isString { w = ""; x = { y = ""; z = ""; q = 42; }; };
      multiWant = [ [ "w" ] [ "x" "y" ] [ "x" "z" ] ];
    };
    {
      check = assert simple == [] || die {
                error  = "Shouldn't have paths when nothing matches";
                result = simple;
              };
              assert nested == nestWant || die {
                error    = "Paths to nested value didn't match expected";
                expected = nestWant;
                result   = nested;
              };
              assert srt multi == multiWant || die {
                error    = "pathsTo failed when multiple results expected";
                expected = multiWant;
                result   = srt multi;
              };
              dummyBuild "pathsTo-check";
    };
}
