{ lib, reverse }:

with lib;
with rec {
  go = x: concatStringsSep "" (reverse (stringToCharacters x));
};
{
  def = assert go "hello" == "olleh";
        assert go ""      == "";
        go;

  tests = {};
}
