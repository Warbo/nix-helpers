{ nixpkgs1803 }:

with builtins;
{
  def   = trace "FIXME: cabal2nix broken on 18.09 due to broken yaml package"
                nixpkgs1803.haskellPackages.haskellSrc2nix;

  tests = {};
}
