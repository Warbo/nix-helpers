{ callMvn2nix, lib, mapNull, mkJar }:
{
  pname,
  version,
  src,
  binaries ? [],
  repository ? callMvn2nix { inherit src; },
  mvnArgs ? null,
  mvnCommands ? null,
}:
mkJar {
  inherit binaries pname version repository src;
  ${mapNull (_: "mvnArgs") mvnArgs} = mvnArgs;
  ${mapNull (_: "mvnCommands") mvnCommands} = mvnCommands;
}
