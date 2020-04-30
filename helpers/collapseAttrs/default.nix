# Turns nested attribute sets into a single level, with dot-separated names.
{ die, hello, lib }:

with builtins;
with lib;
with rec {
  # Recurses through attrsets looking for derivations or non-attrsets. 'path'
  # keeps track of where we are in the overall structure.
  go = path: val:
    if !(isAttrs val) || isDerivation val
       # A leaf: use 'path' to make the attribute name and keep value as-is
       then { "${concatStringsSep "." path}" = val; }
       # An attrset: process every entry, appending their 'path' as needed, and
       # merge all results.
       else fold mergeAttrs
                 {}
                 (map (name: go (path ++ [ name ])
                                (getAttr name val))
                      (attrNames val));
};
rec {
  # Only call 'go' if we've got an attrset (and hence 'path' makes sense)
  def   = val: if !(isAttrs val) || isDerivation val then val else go [] val;
  tests =
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
    {};
}
