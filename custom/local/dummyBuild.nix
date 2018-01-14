{ runCmd }:

name: runCmd "dummy-build-${name}" {} ''mkdir "$out"''
