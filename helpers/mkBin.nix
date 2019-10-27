# Shorthand for making a script via 'wrap' and installing it to a bin/ directory
{ attrsToDirs', bash, runCommand, sanitiseName, wrap }:

with rec {
  go = args: attrsToDirs' (sanitiseName args.name) {
    bin = builtins.listToAttrs [{
      inherit (args) name;
      value = wrap args;
    }];
  };
};
{
  def   = go;
  tests = runCommand "mkBin-test"
    {
      buildInputs = [
        (go {
          name   = "ping";
          script = ''
            #!${bash}/bin/bash
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
    '';
}
