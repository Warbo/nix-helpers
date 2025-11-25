args@{ ... }:
with {
  inherit (import ./. (removeAttrs args [ "inNixShell" ]))
    shellWithHooks
  ;
};
shellWithHooks {
  name = "nix-helpers";
}
