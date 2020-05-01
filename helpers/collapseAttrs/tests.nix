{}:

with rec {
  scalar        = 42;
  scalarResult  = def scalar;
  empty         = def {};
  scalars       = { x = null; y = 42; };
  scalarsResult = def scalars;
  single        = { x = { y = null; }; };
  singleResult  = def single;
  singleWant    = { "x.y" = null; };
  multi         = { x = 42; y = { x = { "a.b" = 123; p = [ hello ]; }; }; };
  multiResult   = def multi;
  multiWant     = { x = 42; "y.x.a.b" = 123; "y.x.p" = [ hello ]; };
};
assert scalar == scalarResult || die {
  inherit scalar scalarResult;
  error = "Collapsing non-set shouldn't change value";
};
assert empty == {} || die {
  inherit empty;
  error  = "Collapsing empty set should give an empty set";
};
assert scalarsResult == scalars || die {
  inherit scalars scalarsResult;
  error = "Collapsing scalars shouldn't change them";
};
assert singleResult == singleWant || die {
  inherit single singleResult singleWant;
  error = "Didn't collapse single entries properly";
};
assert multiWant == multiResult || die {
  inherit multi multiResult multiWant;
  error = "Didn't collapse multiple entries properly";
};
{}
