{
  bash,
  coreutils,
  lib,
  writeScript,
}:

with lib;
with rec {
  makeCommand =
    path: output: with { esc = ''"$'' + output + ''"/${escapeShellArg path}''; }; ''
      if [[ -e ${esc} ]]
      then
        "${coreutils}/bin/rm" -vrf ${esc}
      fi
      true  # End with a success code
    '';

  makeCommands = outputs: p: concatStringsSep "\n" (map (makeCommand p) outputs);
};
pkg: paths:
overrideDerivation pkg (old: {
  builder = writeScript "${old.name}-without-bits" ''
    #!${bash}/bin/bash
    "${old.builder}" "$@"
    ${concatStringsSep "\n" (map (makeCommands (old.outputs or [ "out" ])) paths)}
  '';
})
