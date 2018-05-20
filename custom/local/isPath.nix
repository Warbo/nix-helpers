{ dummyWithEnv, lib }:

with builtins;
with lib;
rec {
  pkg   = x: typeOf x == "path" || (typeOf x == "string" && hasPrefix "/" x);
  tests = [
    (dummyWithEnv {
      name  = "relativePathIsPath";
      value = pkg ./isPath.nix;
    })
    (dummyWithEnv {
      name  = "absolutePathIsPath";
      value = pkg /tmp;
    })
    (dummyWithEnv {
      name  = "pathStringIsPath";
      value = pkg "/tmp";
    })
    (dummyWithEnv {
      name  = "stringIsNotPath";
      value = !(pkg "foo");
    })
    (dummyWithEnv {
      name  = "otherIsNotPath";
      value = !(pkg 42);
    })
  ];
}
