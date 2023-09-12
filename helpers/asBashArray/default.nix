# Render a list of strings into a bash array, e.g. so they can be looped over
# using 'for X in "${Y[@]}"; do ...; done'.
# This should mostly be used for 'static' strings, since they will end up being
# forced; if the strings use import-from-derivation, it might be better to use
# nixListToBashArray (this may or may not be true...)
{ die, fail, lib, runCommand }:

with builtins;
with lib;
l:
assert isList l || die {
  error = "asBashArray expects a list";
  type = typeOf l;
};
assert all isString l || die {
  error = "asBashArray expects strings in the given list";
  types = map typeOf l;
};
"( " + concatStringsSep " " (map lib.escapeShellArg l) + " )"
