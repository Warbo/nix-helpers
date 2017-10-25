{ runCommand }:

name: runCommand "dummy-build-${name}" {} ''mkdir "$out"''
