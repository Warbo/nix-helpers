{ bash, mkBin, runCommand }:

runCommand "mkBin-test" {
  buildInputs = [
    (mkBin {
      name = "ping";
      script = ''
        #!${bash}/bin/bash
        echo "pong"
      '';
    })
  ];
} ''
  X=$(ping)
  [[ "x$X" = "xpong" ]] || {
    echo "Output was '$X'" 1>&2
    exit 1
  }
  echo pass > "$out"
''
