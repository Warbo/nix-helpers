{ bash, coreutils, fail, hello, lib, mupdf, runCommand, writeScript }:

with lib;
with rec {
  makeCommand = path: output:
    with { esc = ''"$'' + output + ''"/${escapeShellArg path}''; };
    ''
      if [[ -e ${esc} ]]
      then
        "${coreutils}/bin/rm" -vrf ${esc}
      fi
      true  # End with a success code
    '';

  makeCommands = outputs: p: concatStringsSep "\n"
                               (map (makeCommand p) outputs);
};
rec {
  def = pkg: paths: overrideDerivation pkg (old: {
          builder = writeScript "${old.name}-without-bits" ''
            #!${bash}/bin/bash
            "${old.builder}" "$@"
            ${concatStringsSep "\n"
                (map (makeCommands (old.outputs or ["out"]))
                     paths)}
          '';
        });

  tests =
    with rec {
      go = { label, pkg, toRemove }: runCommand "can-remove-${label}"
        {
          buildInputs = [ fail ];
          p           = def pkg toRemove;
        }
        ''
          [[ -e "$p" ]] || fail "Dir '$p' not found"
          ${concatStringsSep "\n"
              (map (p: ''[[ -e "$p/${p}" ]] && fail "Didn't remove '$p/${p}'"'')
                   toRemove)}
          mkdir "$out"
        '';
    };
    {
      canRemoveSimple = go {
        label    = "simple-package";
        pkg      = hello;
        toRemove = [ "bin/hello" ];
      };

      canRemoveMultiOutput = go {
        label    = "multi-output-derivation";
        pkg      = mupdf;
        toRemove = [ "bin/mupdf-gl"  "bin/mupdf-x11-curl" ];
      };
    };
}
