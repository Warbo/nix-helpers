{ lib, mkShell, shellHooks }:
args: mkShell (args // {
  shellHook = lib.concatStringsSep "\n"
    (builtins.concatLists [
      [(args.shellHook or "")]
      (args.shellHooks or [])
      shellHooks.defaults
    ]);
})
