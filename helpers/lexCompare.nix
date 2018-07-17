{ bash, dummyBuild, getType, hello, lib }:

with builtins;
with lib;
with rec {
  basic = x: y: if x < y then -1 else if y < x then 1 else 0;
  funcs = {
    callable   = _: _: trace "Warning: Can't compare functions, assuming equal" 0;
    derivation = funcs.set;
    int        = basic;
    list       = compareLists go;
    null       = _: _: 0;
    set        = x: y:
      with rec {
        nX = sort (x: y: basic x y == -1) (attrNames x);
        nY = sort (x: y: basic x y == -1) (attrNames y);
        ns = go nX nY;
      };
      # Compare attr names first; if they differ, return that result.
      if ns != 0
         then ns
         # If names match, check each one in order.
         else fold (n: old: if old != 0
                               then old  # Propagate prior answer if we have one
                               else go (getAttr n x) (getAttr n y))  # Recurse
                   0
                   nX;
    string = basic;
  };

  # Recursive comparison function. If arg types match, look up comparison func.
  go = x: y: if getType x == getType y
                then getAttr (getType x) funcs x y
                # If types are different, compare the type strings instead.
                else getType x < getType y;
};
{
  def   = go;
  tests = {
    checks = assert -1 == go 1          2;
             assert -1 == go "a"        "b";
             assert -1 == go [ 1 ]      [ 2 ];
             assert -1 == go { x = 1; } { x = 2; };
             assert -1 == go { x = 1; } { y = 1; };
             assert  0 == go (x: 1)     (x: 2);
             assert  0 == go null       null;
             assert  0 == go 1          1;
             assert  0 == go "a"        "a";
             assert  0 == go [ 1 ]      [ 1 ];
             assert  0 == go { x = 1; } { x = 1; };
             assert  1 == go 2          1;
             assert  1 == go "b"        "a";
             assert  1 == go [ 2 ]      [ 1 ];
             assert  1 == go { x = 2; } { x = 1; };
             assert  1 == go { y = 1; } { x = 1; };
             assert  0 != go bash hello;
             dummyBuild "lexCompare-checks";
  };
}
