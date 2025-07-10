{ callMvn2nix, catNull, lib, mapNull, mkJar }:
{
  pname,
  version,
  src,
  depsHash ? abort "mkMavenPackage needs depsHash or repository",
  repository ? callMvn2nix { inherit mvnCommands src; hash = depsHash; },
  jarName ? null,
  binaries ? null,
  mvnArgs ? null,
  extraMvnArgs ? null,
  mvnCommands ? null,
  installSteps ? null,
}:
mkJar ({ inherit pname version repository src; } // catNull {
  inherit binaries extraMvnArgs installSteps jarName mvnArgs mvnCommands;
})
