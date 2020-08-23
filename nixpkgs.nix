# Pinned nixpkgs repos
{ lib }:
with rec {
  inherit (builtins) abort attrNames compareVersions getAttr;
  inherit (lib)
    filterAttrs foldl' hasPrefix mapAttrs mapAttrs' replaceStrings stringLength;

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

  latest = attrs:
    with {
      attr = foldl' (found: name: if found == null ||
                                     compareVersions name found == 1
                                     then name
                                     else found)
                    null
                    (attrNames attrs);
    };
    assert attr != null || abort "Can't get latest from empty set";
    getAttr attr attrs;
};

repos // pkgSets // {
  repoLatest    = latest repos;
  nixpkgsLatest = latest pkgSets;
}
