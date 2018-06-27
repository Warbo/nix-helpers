{ die, lib, nothing }:

with builtins;
with lib;
with rec {
  rootPath   = /.;

  stillNeeded  = typeOf (toPath ./.) == "string";
  obsoleteWarn = x:
    if stillNeeded
       then x
       else trace "WARNING: toPath makes paths, is asPath now redundant?" x;

  go = path: if typeOf path == "path"
                then path
                else rootPath + "${path}";
};

{
  def   = obsoleteWarn go;
  tests =
    assert typeOf rootPath == "path" || die {
      error      = "rootPath should be a path";
      actualType = typeOf rootPath;
    };
    assert toString rootPath == "/" || die {
      error    = "rootPath should be /";
      rootPath = toString rootPath;
    };
    assert typeOf (go ./.) == "path" || die {
      error      = "asPath of a path should produce a path";
      actualType = typeOf (go ./.);
    };
    assert toString (go ./.) == toString ./. || die {
      error  = "asPath result didn't match input";
      input  = toString ./.;
      output = toString (go ./.);
    };
    nothing;
}
