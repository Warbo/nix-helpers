# Pinned nixpkgs repos
{
  nixpkgs-lib ? import ../nixpkgs-lib { },
  getNixpkgs ? import ../getNixpkgs { },
}:
with rec {
  inherit (builtins)
    abort
    attrNames
    compareVersions
    getAttr
    mapAttrs
    ;
  inherit (nixpkgs-lib)
    filterAttrs
    foldl'
    hasPrefix
    mapAttrs'
    replaceStrings
    stringLength
    ;

  repos = mapAttrs (_: getNixpkgs) {
    repo1603.tree = "8fc1bade97a4e8adc519ac06a6eb8079ff5f71f9";
    repo1609.tree = "e1a0fb4c11df38d487062f7ec6517c9bb8ae87ed";
    repo1703.tree = "e8ef8d893aef8a762ccee98e3020d59176308c78";
    repo1709.tree = "c0886f076c23c14769295ad853419d9622db7e7d";
    repo1803.tree = "e88c36b8006176c747c5ea1995872948c0f1c721";
    repo1809.tree = "e88c36b8006176c747c5ea1995872948c0f1c721";
    repo1903.tree = "094dc4c21ee25bbd1eea5ab957692c500f8d7f46";
    repo1909.tree = "eda0aadf40b52bf6bfc75660fd8ca82b9f119ead";
    repo2003.tree = "1b3b7a19962f6aa25f03e40234db299e1c8c5b52";
    repo2009.tree = "9e21b3312f8159bce2ae188a69a9e2f371cd2fb8";
    repo2105.tree = "d2652813172f5a5d1f8f6586bc76bdec74fe678d";
    repo2111.tree = "a0894e6ef0233545932b984ff74e7768dc2869c8";
    repo2205.tree = "1d459002073139fa8205c326230010dc52a1fb5b";
    repo2211.tree = "0b35ca1f4901703bd8e40e5cb95cbe768aec4e57";
    repo2305.tree = "acf638af60d50cbb6f060403f903e39216348e0a";
    repo2311.tree = "95e6108c6f5b8cc8d0f2e66978e11e3f435a0cf5";
    repo2405.tree = "c3fb626cbbc8856839bda7b43254204fa5d5f509";
    repo2411.tree = "c8e1d096eca8970320a1d6157b84c2f695426000";
    repo2505.tree = "69a1ca569cb1d40f275bfbdefc5b69843abea40e";
  };

  pkgSets = mapAttrs' (n: v: {
    name = replaceStrings [ "repo" ] [ "nixpkgs" ] n;
    value = import v (
      {
        config = { };
      }
      // (if compareVersions n "repo1703" == -1 then { } else { overlays = [ ]; })
    );
  }) repos;

  latest =
    attrs:
    with {
      attr = foldl' (
        found: name:
        if found == null || compareVersions name found == 1 then name else found
      ) null (attrNames attrs);
    };
    assert attr != null || abort "Can't get latest from empty set";
    getAttr attr attrs;
};

repos
// pkgSets
// {
  repoLatest = latest repos;
  nixpkgsLatest = latest pkgSets;
}
