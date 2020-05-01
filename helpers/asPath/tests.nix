{ asPath, hello, nothing, typeOf }:

with builtins;
assert typeOf rootPath == "path" || die {
  error      = "rootPath should be a path";
  actualType = typeOf rootPath;
};
assert toString rootPath == "/" || die {
  error    = "rootPath should be /";
  rootPath = toString rootPath;
};
assert typeOf (asPath ./.) == "path" || die {
  error      = "asPath of a path should produce a path";
  actualType = typeOf (asPath ./.);
};
assert toString (asPath ./.) == toString ./. || die {
  error  = "asPath result didn't match input";
  input  = toString ./.;
  output = toString (asPath ./.);
};
assert typeOf (asPath "${hello}/bin/hello") == "path" || die {
  error      = "asPath couldn't handle store paths";
  actualType = typeOf (asPath "${hello}/bin/hello");
};
nothing
