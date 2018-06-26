# Traverse nested attribute sets, gathering a list of all derivations we find
{ lib, nothing, withDeps }:

with builtins;
with lib;
with rec {
  go = collect isDerivation;

  testData = rec {
    input = {
      a = 5;
      b = null;
      c = true;
      d = {};
      e = "hello";
      f = { x = nothing; y = nothing; g = []; };
      z = nothing;
    };

    message      = "gotLength should equal shouldLength";
    output       = go input;
    gotLength    = length output;
    shouldLength = 3;
  };

  # We should ignore everything except the derivations ('nothing')
  test = testData.gotLength == testData.shouldLength || abort (toJSON testData);
};
assert test;
{
  pkg   = go;
  tests = withDeps (go { x = nothing; }) nothing;
}
