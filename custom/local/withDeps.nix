# Add extra dependencies to a derivation; for example, if we only want a
# build to succeed if some external tests pass.

{ lib }:

with lib;

deps: drv: overrideDerivation drv (old: {
  extraDeps = (old.extraDeps or []) ++ deps;
})
