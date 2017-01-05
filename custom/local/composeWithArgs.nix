{ lib, withArgsOf }:

with builtins;
with lib;

# Support an "inner-composition" of "f" and "g", which behaves like
# "args: f (g args)" but has explicit named arguments, to allow
# "functionArgs" to work (as used by "callPackage").
f: g: withArgsOf g (args: f (g args))
