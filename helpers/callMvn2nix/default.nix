# Runs mvn2nix and imports the result
{ buildMavenRepositoryFromLockFile, lib, maven, mvn2nix, runCommand, runJq }:
with {
  get = pom: filter: lib.importJSON (runJq {
    inherit filter;
    inputFile = pom;
  });

  mkGoals = goals:
    if goals == []
    then ""
    else lib.concatMapStringsSep " " lib.escapeShellArg (["--goals"] ++ goals);
};
{
  name ? "${pname}-${version}.lock",
  pname ? get pom ".project.artifactId",
  version ? get pom ".project.version",
  pom ? "${src}/pom.xml",
  src ? abort "callMvn2nix requires pom or src",
  hash,
  mvnCommands ? [],
}:
buildMavenRepositoryFromLockFile {
  file = runCommand name
    {
      nativeBuildInputs = [ maven mvn2nix ];
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = hash;
    }
    ''
      cp -r ${src} source
      chmod -R +w source
      cd source
      mvn2nix ${mkGoals mvnCommands} > "$out" || {
        echo "mvn2nix failed. Seeing if mvn has better logs..."
        (
          set -x
          mvn ${lib.concatMapStringsSep " " lib.escapeShellArg mvnCommands}
        )
        exit 1
      } 1>&2
    '';
}
