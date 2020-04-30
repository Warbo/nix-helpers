# Remove a layer of attrset nesting, prefixing the outer names to the inner ones
{ die, lib }:

with lib;
rec {
  def = attrs: listToAttrs
                 (concatLists
                   (mapAttrsToList (outer: mapAttrsToList
                                             (inner: value: {
                                               inherit value;
                                               name = outer + inner;
                                             }))
                                   attrs));

  tests =
    with {
      empty      = def {};
      emptyInner = def { foo = {}; };
      singleGot  = def { foo = { bar = 1; }; };
      singleWant = { foobar = 1; };
      multiGot   = def { foo = { x = 1; y = 2; }; bar = { a = 3; b = 4; }; };
      multiWant  = { foox = 1; fooy = 2; bara = 3; barb = 4; };
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
    {};
}
