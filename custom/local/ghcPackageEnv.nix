{ buildEnv }:

haskellPackages: names: buildEnv {
  name  = "ghc-package-env";
  paths = [ (haskellPackages.ghcWithPackages (p: map (n: p."${n}") names)) ];
}
