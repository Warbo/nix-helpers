{
  die,
  hello,
  lib,
  nothing,
}:

with builtins;
with lib;
with import ./util.nix { };
with {
  # We must discard any existing context, to prevent the Nix error message
  # "a string that refers to a store path cannot be appended to a path". Note
  # that it's safe to do this, because a new context will be created when the
  # resulting path gets converted to a string (e.g. as a derivation attribute).
  go =
    path:
    if typeOf path == "path" then
      path
    else
      rootPath + (unsafeDiscardStringContext "${path}");
};

go
