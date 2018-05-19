{ lib }:

with lib;
with rec {
  go = f: s: concatStringsSep "" (f (stringToCharacters s));
};
{
  pkg   = go;
  tests = [
    (runCommand "stringAsList-test"
      { x = stringAsList (x: x) "hi"; }
      ''echo pass > "$out"'')
  ];
}
