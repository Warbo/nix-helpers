# An awkward compromise between the following constraints:
#  - We want to allow passing arguments to default.nix, so we define a function.
#  - We want nix-shell to call this function automatically so use a set of named
#    arguments (if we just took 'args: ...' then nix-shell gives an error).
#  - statix rejects '{ ... }@args: ...', suggesting 'args: ...' (which nix-shell
#    would reject). Since nix-shell provides an 'inNixShell' arg anyway, we use
#    that to appease statix (using a default value, to keep it optional).
#  - Since default.nix doesn't want the 'inNixShell = true' argument nix-shell
#    passes in, we have to remove it when calling ./.
#  - To prevent deadnix complaining about inNixShell being unused, we merge it
#    into the args set, before using removeAttrs to take it out again!
{
  inNixShell ? false,
  ...
}@args:
with rec {
  argsWithoutInNixShell = removeAttrs ({ inherit inNixShell; } // args) [
    "inNixShell"
  ];
  inherit (import ./. argsWithoutInNixShell)
    shellWithHooks
    ;
};
shellWithHooks {
  name = "nix-helpers";
  src = ./.;
}
