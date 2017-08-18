{ attrsToDirs, writeScript }:

attrsToDirs {
  bin = {
    fail = writeScript "error-logger" ''
      #!/usr/bin/env bash
      echo -e "$*" 1>&2
      exit 1
    '';
  };
}
