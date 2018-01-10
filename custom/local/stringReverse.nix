{ lib, reverse }:

with lib;
with rec {
  go = x: concatStringsSep "" (reverse (stringToCharacters x));
};
assert go "hello" == "olleh";
assert go ""      == "";
go
