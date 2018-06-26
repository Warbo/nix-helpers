# Check whether the given package provides the given binary
{ die, runCommand }:

pkg: bin:
assert builtins.isString bin || die {
  inherit bin pkg;
  error = "bin must be a string";
};
runCommand "have-binary-${bin}"
  {
    inherit bin;
    buildInputs = [ pkg ];
  }
  ''
    command -v "$bin" || exit 1
    echo pass > "$out"
  ''
