{ die, getType }:

with builtins;
with {
  # Is xs a sublist of ys?
  go = xs: ys:
    assert isList xs || die {
      inherit xs;
      error = "First arg of subset must be list";
      type = getType xs;
    };
    assert isList ys || die {
      inherit ys;
      error = "Second arg of subset must be list";
      type = getType ys;
    };
    all (x: elem x ys) xs;
};
assert go [ ] [ ];
assert go [ ] [ 1 2 3 ];
assert go [ 2 1 ] [ 1 2 3 ];
assert !(go [ 2 1 ] [ ]);
assert !(go [ 2 4 ] [ 1 2 3 ]);
go
