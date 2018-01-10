{ lib }:

with lib;
with rec {
  go = f: s: concatStringsSep "" (f (stringToCharacters s));
};
go
