{ callPackage, lib, withArgsOf }:

with builtins;
with lib;

# Support an "inner-composition" of "f" and "g", which behaves like
# "args: f (g args)" but has explicit named arguments, to allow
# "functionArgs" to work (as used by "callPackage").
rec {
  pkg   = f: g: withArgsOf g (args: f (g args));
  tests = [
    (callPackage (pkg (x: x) ({ hello }: hello)) {})
  ];
}
