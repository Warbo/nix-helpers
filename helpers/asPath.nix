{ die, hello, lib, nothing }:

with builtins;
with lib;
with rec {
  rootPath   = /.;

  stillNeeded  = typeOf (toPath ./.) == "string";
  obsoleteWarn = x:
    if stillNeeded
       then x
       else trace "WARNING: toPath makes paths, is asPath now redundant?" x;

  # We must discard any existing context, to prevent the Nix error message
  # "a string that refers to a store path cannot be appended to a path". Note
  # that it's safe to do this, because a new context will be created when the
  # resulting path gets converted to a string (e.g. as a derivation attribute).
  go = path: if typeOf path == "path"
                then path
                else rootPath + (unsafeDiscardStringContext "${path}");
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
    assert typeOf (go "${hello}/bin/hello") == "path" || die {
      error      = "asPath couldn't handle store paths";
      actualType = typeOf (go "${hello}/bin/hello");
    };
    nothing;
}
