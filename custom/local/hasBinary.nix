# Check whether the given package provides the given binary
{ runCommand }:

pkg: bin: runCommand "have-binary-${bin}"
  {
    inherit bin;
    buildInputs = [ pkg ];
  }
  ''
    command -v "$bin" || exit 1
    echo pass > "$out"
  ''
