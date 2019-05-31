{ backtrace, bash, mkBin }:

{
  def = mkBin {
    name   = "fail";
    paths  = [ backtrace bash ];
    script = ''
      #!/usr/bin/env bash
      set -e
      {
        echo -e "$*"
        backtrace
      } 1>&2
      exit 1
    '';
  };

  tests = {};
}
