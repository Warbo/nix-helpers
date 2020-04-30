{ callPackage, hello, isCallable, lib }:

rec {
  def   = x: !(lib.isDerivation x) && !(isCallable x) && builtins.isAttrs x;
  tests = assert def {};
          assert def { x = "y"; };
          assert !(def hello);
          assert !(def (callPackage ({}: x: x) {}));
          assert !(def []);
          assert !(def null);
          {};
}
