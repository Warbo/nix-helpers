# Like typeOf but spots derivations (a subtype of sets) and callables (functions
# or sets with a '__functor' attribute).
{ callPackage, hello, isCallable, lib }:

rec {
  def   = x: if lib.isDerivation x
                then "derivation"
                else if isCallable x
                        then "callable"
                        else builtins.typeOf x;
  tests = assert def                       hello == "derivation";
          assert def                          {} == "set";
          assert def                      (x: x) == "callable";
          assert def (callPackage ({}: x: x) {}) == "callable";
          assert def                          [] == "list";
          {};
}
