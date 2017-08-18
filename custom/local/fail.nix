{ runCommand, writeScript }:

with {
  script = writeScript "error-logger" ''
    #!/usr/bin/env bash
    echo -e "$*" 1>&2
    exit 1
  '';
};
runCommand "mk-fail" { inherit script; } ''
  mkdir -p "$out/bin"
  cp "$script" "$out/bin/fail"
''
