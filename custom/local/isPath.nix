{ dummyWithEnv, lib }:

with builtins;
with lib;
rec {
  pkg   = x: typeOf x == "path" || (typeOf x == "string" && hasPrefix "/" x);
  tests = {
    relative = dummyWithEnv {
      name  = "relativePathIsPath";
      value = pkg ./isPath.nix;
    };
    absolute = dummyWithEnv {
      name  = "absolutePathIsPath";
      value = pkg /tmp;
    };
    pathString = dummyWithEnv {
      name  = "pathStringIsPath";
      value = pkg "/tmp";
    };
    nonPathString = dummyWithEnv {
      name  = "stringIsNotPath";
      value = !(pkg "foo");
    };
    other = dummyWithEnv {
      name  = "otherIsNotPath";
      value = !(pkg 42);
    };
  };
}
