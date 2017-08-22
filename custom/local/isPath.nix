{ lib }:

with builtins;
with lib;

x: typeOf x == "path" || (typeOf x == "string" && hasPrefix "/" x)
