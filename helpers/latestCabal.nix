{ die }:

{
  def = name: die {
    inherit name;
    error    = "deprecated";
    function = "latestCabal";
    message  = ''
      latestCabal is deprecated, since its results aren't reproducible, and
      functions like callHackage, callCabal2nix, haskellSrc2nix, etc. have
      been added to nixpkgs.
    '';
  };

  tests = {};
}
