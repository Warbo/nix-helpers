# Pinned nixpkgs repos
self: super:
with rec {
  inherit (builtins) compareVersions;
  inherit (super.lib)
    filterAttrs hasPrefix mapAttrs mapAttrs' replaceStrings stringLength;

  repos = mapAttrs (_: source: source.outPath)
                   (filterAttrs (n: _: hasPrefix "repo" n &&
                                       stringLength n == 8)
                                (import nix/sources.nix));

  pkgSets = mapAttrs'
    (n: v: {
      name  = replaceStrings [ "repo" ] [ "nixpkgs" ] n;
      value = import v
        ({ config = {}; } // (if compareVersions n "repo1703" == -1
                                 then {}
                                 else { overlays = []; }));
    })
    repos;
};

{
  defs  = repos // pkgSets;
  tests = {
    # One reason to use old nixpkgs versions is for useful but obsolete KDE apps
    canAccessKde =
      assert pkgSets.nixpkgs1603 ? kde4 || self.die {
        error = "nixpkgs1603 doesn't have 'kde4' attribute";
      };
      assert pkgSets.nixpkgs1603.callPackage
               ({ kde4 ? null }: kde4 != null) {} || self.die {
        error = "nixpkgs1603.callPackage should populate 'kde4' argument";
      };
      self.nothing;
  };
}
