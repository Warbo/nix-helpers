# Copy the contents of a bunch of directories into one
{ runCommand }:

with builtins;

dirs: runCommand "merged-dirs" { dirs = map toString dirs; } ''
  shopt -s nullglob
  mkdir -p "$out"

  for D in $dirs
  do
    for F in "$D"/*
    do
      cp -as "$F" "$out"/
    done
    chmod +w -R "$out"
  done
''
