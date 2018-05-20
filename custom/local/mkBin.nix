# Shorthand for making a script via 'wrap' and installing it to a bin/ directory
{ attrsToDirs, runCommand, wrap }:

with rec {
  go = args: attrsToDirs {
    bin = builtins.listToAttrs [{
      inherit (args) name;
      value = wrap args;
    }];
  };
};
{
  pkg   = go;
  tests = [
    (runCommand "mkBin-test"
      {
        buildInputs = [
          (go {
            name   = "ping";
            script = ''
              #!/usr/bin/env bash
              echo "pong"
            '';
          })
        ];
      }
      ''
        X=$(ping)
        [[ "x$X" = "xpong" ]] || {
          echo "Output was '$X'" 1>&2
          exit 1
        }
        echo pass > "$out"
      '')
  ];
}
