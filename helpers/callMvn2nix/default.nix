# Runs mvn2nix and imports the result
{ buildMavenRepositoryFromLockFile, lib, mvn2nix, runCommand, runJq }:
with {
  get = pom: filter: lib.importJSON (runJq {
    inherit filter;
    inputFile = pom;
  });
};
{
  name ? "${pname}-${version}.lock",
  pname ? get pom ".project.artifactId",
  version ? get pom ".project.version",
  pom ? "${src}/pom.xml",
  src ? abort "callMvn2nix requires pom or src",
  hash ? null,
}:
buildMavenRepositoryFromLockFile {
  file = runCommand name
    {
      nativeBuildInputs = [ mvn2nix ];
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = hash;
    }
    ''
      cp -r ${src} source
      chmod -R +w source
      cd source
      mvn2nix > "$out"
    '';
}
