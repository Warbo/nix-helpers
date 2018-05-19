# Shorthand for making a script via 'wrap' and installing it to a bin/ directory
{ attrsToDirs, wrap }:

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
          fail
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
        [[ "x$X" = "xpong" ]] || fail "Output was '$X'"
        echo pass > "$out"
      '')
  ];
}
