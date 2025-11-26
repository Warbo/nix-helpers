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
    file = ./nix_release_eval.sh;
    vars.EXPR = escapeShellArg (
      "("
      + concatStringsSep " " [
        ''with { raw = import (./. + ("/" + (builtins.getEnv "F"))); };''
        "with { val = if builtins.isAttrs raw then raw else raw {}; };"
        ''(import "${cleanSource ../..}").drvPathsIn val''
      ]
      + ")"
    );
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
    vars.NIX_RELEASE_EVAL = nix_release_eval;
  };
};
attrsToDirs' "nix_release" {
  bin = {
    inherit nix_release nix_release_eval;
  };
}
