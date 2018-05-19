{ dummyWithEnv, lib }:

with builtins;
with lib;
with {
  go = x: typeOf x == "path" || (typeOf x == "string" && hasPrefix "/" x);
};
{
  pkg   = go;
  tests = [
    (dummyWithEnv {
      name  = "relativePathIsPath";
      value = isPath ./isPath.nix;
    })
    (dummyWithEnv {
      name  = "absolutePathIsPath";
      value = isPath /tmp;
    })
    (dummyWithEnv {
      name  = "pathStringIsPath";
      value = isPath "/tmp";
    })
    (dummyWithEnv {
      name  = "stringIsNotPath";
      value = !(isPath "foo");
    })
    (dummyWithEnv {
      name  = "otherIsNotPath";
      value = !(isPath 42);
    })
  ];
}
