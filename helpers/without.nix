{ bash, coreutils, hello, lib, writeScript }:

with {
  mkCmd = p: ''
    [[ -e "$out" ]] && "${coreutils}/bin/rm" -rf "$out"/${lib.escapeShellArg p}
  '';
};
rec {
  def = pkg: paths: lib.overrideDerivation pkg (old: {
          builder = writeScript "${old.name}-without-bits" ''
            #!${bash}/bin/bash
            "${old.builder}" "$@"
            ${lib.concatStringsSep "\n" (map mkCmd paths)}
          '';
        });

  tests = {
    canRemoveHello = runCommand "can-remove-hello"
      {
        buildInputs = [ fail ];
        p           = def hello [ "bin/hello" ];
      }
      ''
        [[ -e "$p"           ]] || fail "Dir '$p' not found"
        [[ -e "$p/bin/hello" ]] && fail "Didn't remove '$p/bin/hello'"
        mkdir "$out"
      '';
  };
}
