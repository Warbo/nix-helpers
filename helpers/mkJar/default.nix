{
  jdk,
  lib,
  makeWrapper,
  maven,
  stdenv,
}:
{
  pname,
  version,
  repository,
  src,
  jarName ? "${pname}-${version}.jar",
  binaries ? [ ],
  mvnArgs ? [
    "--offline"
    "-Dmaven.repo.local=${repository}"
  ]
  ++ mvnCommands,
  mvnCommands ? [ "package" ],
  extraMvnArgs ? [ ],
  extraAttrs ? { },
  installSteps ? [
    ''cp target/${jarName} "$out/"''
  ]
  ++ map (b: ''
    makeWrapper ${jdk}/bin/java "$out/bin/${b}" \
                --add-flags "-jar $out/${jarName}" \
                --set M2_HOME ${maven} \
                --set JAVA_HOME ${jdk}
  '') binaries,
  installPhase ? lib.concatStringsSep "\n" (
    [ ''mkdir "$out"; ln -s ${repository} $out/lib'' ] ++ installSteps
  ),
}:
stdenv.mkDerivation (
  rec {
    inherit
      installPhase
      pname
      version
      src
      ;
    name = "${pname}-${version}";
    buildInputs = [
      jdk
      makeWrapper
      maven
    ];
    buildPhase = lib.concatMapStringsSep " " lib.escapeShellArg (
      [ "mvn" ] ++ mvnArgs ++ extraMvnArgs
    );
  }
  // extraAttrs
)
