# Evaluate and/or build all derivations in a release.nix file
{ attrsToDirs', bash, fail, git, lib, gnutar, withNix, wrap }:

with rec {
  inherit (lib) cleanSource concatStringsSep escapeShellArg;

  nix_release_eval = wrap {
    name   = "nix_release_eval";
    paths  = [ bash fail ];
    script = ''
      #!${bash}/bin/bash
      set -e

      [[ -n "$1" ]] && F="$1"
      [[ -z "$F" ]] && [[ -e     release.nix ]] && F='release.nix'
      [[ -z "$F" ]] && [[ -e nix/release.nix ]] && F='nix/release.nix'
      [[ -z "$F" ]] && [[ -e     default.nix ]] && F='default.nix'
      [[ -z "$F" ]] && [[ -e nix/default.nix ]] && F='nix/default.nix'
      [[ -z "$F" ]] &&
        fail "Error: No file given and didn't find release.nix or default.nix"

      echo "Finding derivations from '$F'" 1>&2
      F="$F" nix eval --show-trace --raw ${
        escapeShellArg ("(" + concatStringsSep " " [
          ''with { raw = import (./. + ("/" + (builtins.getEnv "F"))); };''
          ''with { val = if builtins.isAttrs raw then raw else raw {}; };''
          ''(import "${cleanSource ../..}").drvPathsIn val''
        ] + ")")
      }
    '';
  };

  nix_release = wrap {
    name  = "nix_release";
    file  = ./nix_release.sh;
    paths = (withNix {}).buildInputs ++ [ bash fail git gnutar ];
    vars  = { inherit nix_release_eval; };
  };
};
attrsToDirs' "nix_release" {
  bin = { inherit nix_release nix_release_eval; };
}
