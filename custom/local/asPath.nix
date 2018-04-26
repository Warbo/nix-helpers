{ die, lib }:

with builtins;
with lib;
with rec {
  herePath   = ./.;
  hereString = toString herePath;
  hereDepth  = length (filter (x: x == "/") (stringToCharacters hereString));
  upDots     = concatStringsSep "/" (map (_: "..") (range 1 hereDepth));
  rootPath   = ./. + "/${upDots}";

  stillNeeded  = typeOf (toPath herePath) == "string";
  obsoleteWarn = x:
    if stillNeeded
       then x
       else trace "WARNING: toPath makes paths, is asPath now redundant?" x;

  go = path: if typeOf path == "path"
                then path
                else rootPath + "${path}";
};

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
obsoleteWarn go
