# Merge together a list of attrsets
{ die, lib }:

with lib;
rec {
  def   = fold (x: y: x // y) {};

  tests =
    assert with {
      want = {};
      got  = def [];
    };
    got == want || die {
      inherit got want;
      error = "Should get {} for 'merge []'";
    };
    assert with rec {
      want = { x = 1; y = "2"; };
      got  = def [want];
    };
    got == want || die {
      inherit got want;
      error = "Merging one attrset should leave it alone";
    };
    assert with {
      want = { x = 1; y = "2"; z = true; };
      got  = def [ { x = 1; y = "2"; } { z = true; } ];
    };
    got == want || die {
      inherit got want;
      error = "Failed to merge";
    };
    {};
}
