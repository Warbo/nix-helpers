{ isBroken, lib, runCommand }:

with import ./util.nix { inherit lib; };
with {
  testStillNeeded =
    if needWorkaround
       then {
         workaroundStillNeeded =
           isBroken (runCommand "withNix-workaround-needed"
             (withNix { NIX_REMOTE = "daemon"; })
             ''
               nix-build -E '(import <nixpkgs> {}).hello'
               mkdir "$out"
             '');
       }
       else {};
};
testStillNeeded // {
  canEvalNumbers = runCommand "withNix-can-eval-number" (withNix {}) ''
    X=$(nix-instantiate --eval -E '1 + 2')
    [[ "$X" -eq 3 ]] || {
      echo "Expected 3, got '$X'" 1>&2
      exit 1
    }
    mkdir "$out"
  '';
  canEvalDerivations = runCommand "withNix-can-eval-derivation" (withNix {}) ''
    X=$(nix-instantiate --eval -E '(import <nixpkgs> {}).hello') || {
      echo "$X" 1>&2
      exit 1
    }
    mkdir "$out"
  '';
  canInstantiate = runCommand "withNix-can-instantiate" (withNix {}) ''
    unset NIX_LOG_FD
    nix-instantiate -E '(import <nixpkgs> {}).hello'
    mkdir "$out"
  '';
  canRealise = runCommand "withNix-can-realise" (withNix {}) ''
    DRV=$(nix-instantiate -E '(import <nixpkgs> {}).hello') || {
      echo "$DRV" 1>&2
      exit 1
    }
    nix-store --realise "$DRV"
    mkdir "$out"
  '';
  canShell = runCommand "withNix-can-shell" (withNix {}) ''
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
  canBuildHello = runCommand "withNix-can-build-hello" (withNix {}) ''
    nix-build --show-trace --no-out-link -E 'with import <nixpkgs> {}; hello'
    mkdir "$out"
  '';
  canAccessFiles = runCommand "withNix-can-access-files" (withNix {}) ''
    echo "<nixpkgs>" > ./test.nix
    nix-build --show-trace -E '(import (import ./test.nix) {}).hello'
    mkdir "$out"
  '';
}
