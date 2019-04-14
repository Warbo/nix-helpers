{ haskellPackages, nixpkgs1803 }:

{
  def   =             haskellPackages.haskellSrc2nix or
          nixpkgs1803.haskellPackages.haskellSrc2nix;

  tests = {};
}
