{ die, nothing, pinnedNixpkgs }:

{
  # One reason to use old nixpkgs versions is for useful but obsolete KDE apps
  canAccessKde =
    assert pinnedNixpkgs.nixpkgs1603 ? kde4 || die {
      error = "nixpkgs1603 doesn't have 'kde4' attribute";
    };
    assert pinnedNixpkgs.nixpkgs1603.callPackage
      ({ kde4 ? null }: kde4 != null) {} || die {
        error = "nixpkgs1603.callPackage should populate 'kde4' argument";
      };
    nothing;
}
