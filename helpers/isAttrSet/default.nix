{ callPackage, hello, isCallable, lib }:

x:
!(lib.isDerivation x) && !(isCallable x) && builtins.isAttrs x
