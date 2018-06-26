{ lib, runCommand }:

with lib;
rec {
  def   = f: s: concatStringsSep "" (f (stringToCharacters s));
  tests = runCommand "stringAsList-test" { x = def (x: x) "hi"; } ''
    echo pass > "$out"
  '';
}
