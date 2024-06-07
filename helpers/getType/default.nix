# Like typeOf but spots derivations (a subtype of sets) and callables (functions
# or sets with a '__functor' attribute).
{
  callPackage,
  hello,
  isCallable,
  lib,
}:

x:
if lib.isDerivation x then
  "derivation"
else if isCallable x then
  "callable"
else
  builtins.typeOf x
