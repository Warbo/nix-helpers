{ dummyWithEnv, isPath }:

{
  relative = dummyWithEnv {
    name  = "relativePathIsPath";
    value =   isPath ./isPath.nix;
  };
  absolute = dummyWithEnv {
    name  = "absolutePathIsPath";
    value =   isPath /tmp;
  };
  pathString = dummyWithEnv {
    name  = "pathStringIsPath";
    value =   isPath "/tmp";
  };
  nonPathString = dummyWithEnv {
    name  = "stringIsNotPath";
    value = !(isPath "foo");
  };
  other = dummyWithEnv {
    name  = "otherIsNotPath";
    value = !(isPath 42);
  };
}
