{ dummyWithEnv, lib }:

with builtins;
with lib;
rec {
  def   = x: typeOf x == "path" || (typeOf x == "string" && hasPrefix "/" x);
  tests = {
    relative = dummyWithEnv {
      name  = "relativePathIsPath";
      value = def ./isPath.nix;
    };
    absolute = dummyWithEnv {
      name  = "absolutePathIsPath";
      value = def /tmp;
    };
    pathString = dummyWithEnv {
      name  = "pathStringIsPath";
      value = def "/tmp";
    };
    nonPathString = dummyWithEnv {
      name  = "stringIsNotPath";
      value = !(def "foo");
    };
    other = dummyWithEnv {
      name  = "otherIsNotPath";
      value = !(def 42);
    };
  };
}
