# Add extra dependencies to a derivation; for example, if we only want a
# build to succeed if some external tests pass. This version allows the name to
# be overridden too, e.g. so we can add a test suite to "foo-untested" and
# rename it to "foo". The "withDeps" function avoids renaming.

{ lib }:

with lib;
name: deps: drv:
overrideDerivation drv (
  old:
  (if name == null then { } else { inherit name; })
  // {
    extraDeps = (old.extraDeps or [ ]) ++ deps;
  }
)
