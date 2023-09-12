{ lib, runCommand }:

with lib;
f: s:
concatStringsSep "" (f (stringToCharacters s))
