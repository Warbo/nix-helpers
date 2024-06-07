# Evaluate and/or build all derivations in a release.nix file
{
  attrsToDirs',
  bash,
  fail,
  git,
  lib,
  gnutar,
  wrap,
}:

with rec {
  inherit (lib) cleanSource concatStringsSep escapeShellArg;

  # TODO: It might be better to check if the import is callable, rather than
  # not-an-attrset. In particular, it would be nice to support {__functor = ...}
  nix_release_eval = wrap {
    name = "nix_release_eval";
    paths = [
      bash
      fail
    ];
    script = ''
      #!${bash}/bin/bash
      set -e

      if [[ "x$1" = "x-h" ]] || [[ "x$1" = "x--help" ]] || [[ "x$1" = "x-?" ]]
      then
        {
          echo "nix_release_eval: Find all Nix derivations defined in a file"
          echo
          echo "Set the F env var to the path you'd like to import. If F is not"
          echo "set, we default to looking for a ./release.nix file, then"
          echo "./nix/release.nix, then ./default.nix and finally"
          echo "./nix/default.nix; the first one found will be used, or we abort"
          echo "if none is found."
          echo
          echo "We import this path in a Nix derivation, and check if it's an"
          echo "attrset; if so, we look through it recursively for derivations."
          echo "If it's not an attrset, we try calling it with argument '{}'"
          echo "and search for derivations in the result. This behaviour works"
          echo "well for functions with default arguments, since it avoids the"
          echo "need for a separate .nix file just to perform that call."
        } 1>&2
        exit 0
      fi

      [[ -n "$1" ]] && F="$1"
      [[ -z "$F" ]] && [[ -e     release.nix ]] && F='release.nix'
      [[ -z "$F" ]] && [[ -e nix/release.nix ]] && F='nix/release.nix'
      [[ -z "$F" ]] && [[ -e     default.nix ]] && F='default.nix'
      [[ -z "$F" ]] && [[ -e nix/default.nix ]] && F='nix/default.nix'
      [[ -z "$F" ]] &&
        fail "Error: No file given and didn't find release.nix or default.nix"

      echo "Finding derivations from '$F'" 1>&2
      F="$F" nix eval --show-trace --raw ${
        escapeShellArg (
          "("
          + concatStringsSep " " [
            ''with { raw = import (./. + ("/" + (builtins.getEnv "F"))); };''
            "with { val = if builtins.isAttrs raw then raw else raw {}; };"
            ''(import "${cleanSource ../..}").drvPathsIn val''
          ]
          + ")"
        )
      }
    '';
  };

  nix_release = wrap {
    name = "nix_release";
    file = ./nix_release.sh;
    paths = [
      bash
      fail
      git
      gnutar
    ];
    vars = {
      inherit nix_release_eval;
    };
  };
};
attrsToDirs' "nix_release" {
  bin = {
    inherit nix_release nix_release_eval;
  };
}
