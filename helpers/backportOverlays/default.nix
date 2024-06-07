# Allows nixpkgs overlays to be used with nixpkgs repositories prior to 17.03.
# We use the old 'packageOverrides' config value to emulate the behaviour of
# 'overrides'.
{
  attrsToDirs',
  nixpkgs-lib,
  writeScript,
}:

# The 'name' is just used for the Nix store names. The 'repo' should be an old
# (pre 17.03) nixpkgs repo; either a derivation (like 'fetchgit {...}') or a
# path, or a string of a path. Returns a derivation which can be used in place
# of the 'repo' argument, for example:
#
#     with import (backportOverlays {...}) { overlays = [ ... ]; }; myPkg
#
{ name, repo }:
with { clean-helpers = nixpkgs-lib.cleanSource ../..; };
attrsToDirs' name {
  "default.nix" = writeScript "${name}-default.nix" ''
    { overlays ? [], ... }@args:
      with rec {
        inherit (import "${clean-helpers}" {}) nixpkgs-lib;
        inherit (nixpkgs-lib) fix foldl;
      };
      fix
        (self: import "${repo}" (removeAttrs args [ "overlays" ] // {
          config = (args.config or {}) // {
            packageOverrides = super:
              foldl (old: f: old // f self super) {} overlays;
            };
        }))
  '';
}
