# Turns a fixed-output derivation (like fetchgit or fetchurl) into a normal
# derivation. This can be useful if we know its hash isn't going to work.
{ lib }:

{
  def = drv: lib.overrideDerivation drv (old: {
    outputHash     = null;
    outputHashAlgo = null;
    outputHashMode = null;
    sha256         = null;
  });

  tests = {};
}
