{ runCommand }:

{ name, path }:
runCommand name { inherit path; } ''
  ln -s "$path" "$out"
''
