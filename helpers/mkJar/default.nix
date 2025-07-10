{ jdk, lib, makeWrapper, maven, stdenv }:
{
  pname,
  version,
  repository,
  src,
  binaries ? [],
  mvnArgs ? [ "--offline" "-Dmaven.repo.local=${repository}" ] ++ mvnCommands,
  mvnCommands ? [ "package" ],
}:
stdenv.mkDerivation rec {
  inherit pname version src;
  name = "${pname}-${version}";
  buildInputs = [ jdk makeWrapper maven ];
  buildPhase = ''
    mvn ${lib.concatMapStringsSep " " lib.escapeShellArg mvnArgs}
  '';
  installPhase = ''
    mkdir "$out"
    cp target/${name}.jar "$out/"
    ln -s ${repository} $out/lib
    ${
      lib.concatMapStringsSep
        "\n"
        (b: ''
          makeWrapper ${jdk}/bin/java "$out/bin/${b}" \
            --add-flags "-jar $out/${name}.jar" \
            --set M2_HOME ${maven} \
            --set JAVA_HOME ${jdk}
        '')
        binaries
    }
  '';
}
