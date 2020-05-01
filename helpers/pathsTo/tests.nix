{ die, dummyBuild, lexSort, pathsTo }:

with rec {
  inherit (builtins) isString;
  simple    = pathsTo isString { x = 42; };
  nested    = pathsTo isString { x = { y = { z = "hello"; }; }; };
  nestWant  = [ [ "x" "y" "z" ] ];
  multi     = pathsTo isString { w = ""; x = { y = ""; z = ""; q = 42; }; };
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
  assert lexSort multi == multiWant || die {
    error    = "pathsTo failed when multiple results expected";
    expected = multiWant;
    result   = lexSort multi;
  };
  dummyBuild "pathsTo-check";
}
