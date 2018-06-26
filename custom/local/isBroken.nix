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

    echo "isBroken: ${old.name} failed to build, as we expected" 1>&2

    echo "Generating outputs [$outputs] to appease Nix" 1>&2
    for O_STRING in $outputs
    do
      O_PATH="${"$" + "{!O_STRING}"}"
      if [[ -e "$O_PATH" ]]
      then
        echo "Cleaning up '$O_PATH' after build" 1>&2
        "${coreutils}/bin/rm" -rf "$O_PATH"
      fi

      echo "Failed as expected" > "$O_PATH"
    done
  '';
})
