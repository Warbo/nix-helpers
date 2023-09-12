{ runCmd }:

{ name, value }:
runCmd "${name}" { inherit value; } ''mkdir "$out"''
