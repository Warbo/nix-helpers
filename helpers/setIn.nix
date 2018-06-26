# Add a value somewhere inside a nested set of attributes, based on a path
{ dummyWithEnv, lib }:
with builtins;
with lib;
with rec {
  # The actual function
  go = { path, value, set }:
    with rec {
      name = head path;
      new  = if length path == 1
                then value
                else go {
                  inherit value;
                  path = (tail path);
                  set  = set."${name}" or {};
                };
    };
    set // { "${name}" = new; };

  # Unit test
  testData = rec {
    inputPath  = [ "x" "y" "z" ];
    inputValue = 1337;
    inputSet   = {
      a = { b = 1; c = null; };
      b = [ "foo" "bar" ];
      x = {
        a = 1;
        y = {
          a = 42;
          b = null;
        };
      };
    };

    expected = {
      a = { b = 1; c = null; };
      b = [ "foo" "bar" ];
      x = {
        a = 1;
        y = {
          a = 42;
          b = null;
          z = 1337;
        };
      };
    };

    got     = go { path = inputPath; value = inputValue; set = inputSet; };
    message = "'got' should match 'expected'";
    result  = got == expected;
  };

  test = testData.result || abort (toJSON testData);
};
assert test;
{
  pkg   = go;
  tests = dummyWithEnv {
    name  = "setIn-test";
    value = toJSON (go {
      path  = [ "x" ];
      value = 1;
      set   = {};
    });
  };
}
