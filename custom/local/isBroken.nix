{ bash, coreutils, stdenv, writeScript }:

toFail: stdenv.lib.overrideDerivation toFail (old: {
  builder = writeScript "toFail-${old.name}" ''
    #!${bash}/bin/bash
    echo "Ensuring that ${old.name} fails to build" 1>&2
    if "${old.builder}" ${builtins.concatStringsSep " " old.args}
    then
      echo "Error: ${old.name} succeeded but should have failed" 1>&2
      exit 1
    fi

    echo "shouldFail: ${old.name} failed to build, as we expected" 1>&2
    if [[ -e "$out" ]]
    then
      echo "Cleaning up after build" 1>&2
      "${coreutils}/bin/rm" -r "$out"
    fi
    echo "Failed as expected" > "$out"
  '';
})
