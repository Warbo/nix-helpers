{ runCmd }:

{ name, value }: runCmd "dummy-build-${name}"
                        { inherit value; }
                        ''mkdir "$out"''
