{ lib, runCommand }:

with lib;
rec {
  pkg   = f: s: concatStringsSep "" (f (stringToCharacters s));
  tests = runCommand "stringAsList-test" { x = pkg (x: x) "hi"; } ''
    echo pass > "$out"
  '';
}
