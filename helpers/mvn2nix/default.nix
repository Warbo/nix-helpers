# mvn2nix creates a "lock file" specifying the dependencies of a Maven project.
# It provides a derivation, but its pinned dependencies are out of date; which
# unfortunately makes its lock files incompatible with newer versions of Maven
# (in particular it locks old versions of maven-resources-plugin, so newer Maven
# versions can't find the new version that they need).
# We overcome that by re-bootstrapping.
{
  callPackage,
  hash ? "sha256-ROPgBNuC0/28YUB1uTB4Xi9zYl4RGerVqI+mDIuYduA=",
  jdk,
  maven,
  mkMavenPackage,
  writeShellApplication,
}:
# The derivation provided by mvn2nix hard-codes the 'repository' argument, so we
# can't just call it with an updated version. That derivation is doing basically
# the same thing as mkJar, so we can use the latter instead.
mkMavenPackage rec {
  pname = "mvn2nix";
  version = "0.1";
  src = import ./source.nix;
  binaries = [ "mvn2nix" ];
  # Use a "bootstrap" version of mvn2nix in order to get its own dependencies
  repository =
    callPackage ../callMvn2nix
      {
        # runJq is only needed if we don't provide pname & version
        runJq = null;

        # This comes from the mvn2nix repo but it doesn't depend on mvn2nix itself
        buildMavenRepositoryFromLockFile =
          callPackage ../buildMavenRepositoryFromLockFile
            { };

        # The mvn2nix executable provided by its repo does essentially the same as
        # this (but using 'makeWrapper' instead of 'writeShellApplication').
        mvn2nix = writeShellApplication {
          name = pname;
          runtimeEnv = {
            # Hard-code the versions we're given, rather than the old pinned ones
            M2_HOME = "${maven}";
            JAVA_HOME = "${jdk}";
          };
          runtimeInputs = [ jdk ];
          text = ''
            exec java -jar ${(import src { }).mvn2nix}/mvn2nix-0.1.jar "$@"
          '';
        };
      }
      {
        inherit
          hash
          pname
          src
          version
          ;
      };
}
