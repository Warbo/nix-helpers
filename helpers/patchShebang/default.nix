# Replaces /usr/bin/env in shebangs, since it doesn't exist in sandboxes
{ attrsToDirs', coreutils, die, dummyBuild, fail, lib, runCommand, sanitiseName
, writeScript }:

with builtins;
with lib;
with rec {
  # Splits off the first line of the given string, to give { first; rest; }
  splitLine = first: s:
    with {
      char = substring 0 1 s;
      rest = substring 1 (stringLength s) s;
    };
    if s == "" || char == "\n" then {
      inherit first rest;
    } else
      splitLine (first + char) rest;

  patchString = s:
    if hasPrefix "#!" s then
      with splitLine "" s;
      concatStringsSep "\n" [
        (replaceStrings [ "/usr/bin/env" ] [ "${coreutils}/bin/env" ] first)
        rest
      ]
    else
      s;

  patchFiles = name: dir: given:
    runCommand (if name == null then
      "${unsafeDiscardStringContext (baseNameOf "${given}")}"
    else
      name) { inherit given; } ''
        cp -L ${if dir then "-r" else ""} "$given" "$out"
        chmod +w -R "$out"
        while read -r F
        do
          sed -i "$F" -e '1 s@^#! */usr/bin/env@#!${coreutils}/bin/env@'
        done < <(find "$out" -type f)
      '';
};
{ dir ? null, file ? null, name ? null, string ? null }:
with {
  count = fold (x: count: if x == null then count + 1 else count) 0 [
    string
    file
    dir
  ];
};
assert count == 2 || die {
  inherit name;
  error = "Exactly 1 patchShebang arg must be non-null";
  dir = typeOf dir;
  file = typeOf file;
  string = typeOf string;
};
if string != null then
  patchString string
else if dir == null then
  patchFiles name false file
else
  patchFiles name true dir
