{ die, merge }:

assert with {
    want = {};
    got  = merge [];
  };
  got == want || die {
    inherit got want;
    error = "Should get {} for 'merge []'";
  };
assert with rec {
    want = { x = 1; y = "2"; };
    got  = merge [want];
  };
  got == want || die {
    inherit got want;
    error = "Merging one attrset should leave it alone";
  };
assert with {
    want = { x = 1; y = "2"; z = true; };
    got  = merge [ { x = 1; y = "2"; } { z = true; } ];
  };
  got == want || die {
    inherit got want;
    error = "Failed to merge";
  };
{}
