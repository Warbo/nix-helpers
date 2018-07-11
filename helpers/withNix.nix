# Augment the environment for a derivation by allowing Nix commands to be
# called inside the build process

{ attrsToDirs, bash, isBroken, lib, nix, nixpkgs1709, openssh, runCommand,
  sshpass, wrap }:

with builtins;
with lib;
with rec {
  wrapper = cmd: wrap {
    name   = "cmd-wrapped";
    paths  = [ bash openssh sshpass ];
    vars   = {
      SSHPASS = "nixbuildtrampoline";
    };
    script = ''
      #!/usr/bin/env bash
      ARGS=""
      for ARG in "$@"
      do
        ESC=$(printf "%s" "$ARG" | sed -e "s/'/'\\\\${"''"}/g")
        ARGS="$ARGS '$ESC'"
      done
      echo "ARGS: $ARGS" 1>&2
      sshpass -e ssh -o "StrictHostKeyChecking no" nixbuildtrampoline@localhost PATH="$PATH" "${nix}/bin/${cmd}" "$ARGS"
    '';
  };

  wrappedNix = attrsToDirs {
    bin = genAttrs [ "nix-build" "nix-instantiate" "nix-shell" "nix-store" ]
                   wrapper;
  };

  vars = {
    NIX_PATH    = if getEnv "NIX_PATH" == ""
                     then "nixpkgs=${<nixpkgs>}"
                     else getEnv "NIX_PATH";
    NIX_REMOTE  = if getEnv "NIX_REMOTE" == ""
                     then "daemon"
                     else getEnv "NIX_REMOTE";
  };

  go = attrs: vars // attrs // {
    buildInputs = (attrs.buildInputs or []) ++ [ wrappedNix ];
  };
};
{
  def   = go;
  tests = {
    workaroundStillNeeded = isBroken (runCommand "withNix-workaround-needed"
      (vars // { buildInputs = [ nix.out ]; })
      ''
        nix-build -E '(import <nixpkgs> {}).hello'
        mkdir "$out"
      '');
    canEvalNumbers = runCommand "withNix-can-eval-number" (go {}) ''
      X=$(nix-instantiate --eval -E '1 + 2')
      [[ "$X" -eq 3 ]] || {
        echo "Expected 3, got '$X'" 1>&2
        exit 1
      }
      mkdir "$out"
    '';
    canEvalDerivations = runCommand "withNix-can-eval-derivation" (go {}) ''
      X=$(nix-instantiate --eval -E '(import <nixpkgs> {}).hello') || {
        echo "$X" 1>&2
        exit 1
      }
      mkdir "$out"
    '';
    canInstantiate = runCommand "withNix-can-instantiate" (go {}) ''
      unset NIX_LOG_FD
      nix-instantiate -E '(import <nixpkgs> {}).hello'
      mkdir "$out"
    '';
    canRealise = runCommand "withNix-can-realise" (go {}) ''
      DRV=$(nix-instantiate -E '(import <nixpkgs> {}).hello') || {
        echo "$DRV" 1>&2
        exit 1
      }
      nix-store --realise "$DRV"
      mkdir "$out"
    '';
    canShell = runCommand "withNix-can-shell" (go {}) ''
      X=$(nix-shell -p hello --run 'echo 42') || {
        echo "$X" 1>&2
        exit 1
      }
      [[ "$X" -eq 42 ]] || {
        echo "Expected 42 got '$X'" 1>&2
        exit 1
      }
      mkdir "$out"
    '';
    canBuildHello = runCommand "withNix-can-build-hello" (go {}) ''
      nix-build --show-trace --no-out-link -E 'with import <nixpkgs> {}; hello'
      mkdir "$out"
    '';
  };
}
