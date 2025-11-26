{ lib, mkShell, git-hooks, shellHooks }:
{ src, ... }@args:
with {
  pre-commit = git-hooks.run ((args.pre-commit or {}) // {
    inherit src;
    hooks = lib.recursiveUpdate
      git-hooks.defaultHooks
      (args.pre-commit.hooks or {});
  });
};
mkShell (removeAttrs args [ "pre-commit" "src" ] // {
  buildInputs = (args.buildInputs or []) ++ [
    pre-commit.enabledPackages
  ];
  shellHook = lib.concatStringsSep "\n"
    (builtins.concatLists [
      [
        (args.shellHook or "")
        pre-commit.shellHook
      ]
      (args.shellHooks or [])
      shellHooks.defaults
    ]);
})
