{ die, prefixFlatten }:

with {
  empty      = prefixFlatten {};
  emptyInner = prefixFlatten { foo = {}; };
  singleWant = { foobar = 1; };
  singleGot  = prefixFlatten { foo = { bar = 1; }; };
  multiWant  = { foox = 1; fooy = 2; bara = 3; barb = 4; };
  multiGot   = prefixFlatten {
    foo = { x = 1; y = 2; }; bar = { a = 3; b = 4; };
  };
};
assert empty == {} || die {
  got   = empty;
  want  = {};
  error = "prefixFlatten should leave empty attrsets alone";
};
assert emptyInner == {} || die {
  got   = emptyInner;
  want  = {};
  error = "prefixFlatten should give";
};
assert singleGot == singleWant || die {
  got   = singleGot;
  want  = singleWant;
  error = "prefixFlatten should prefix inner name";
};
assert multiGot == multiWant || {
  got   = multiGot;
  want  = multiWant;
  error = "prefixFree should prefix each name";
};
{}
