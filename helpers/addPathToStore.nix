# Adding files to the Nix store in a general way turns out to be quite tricky.
# In particular:
#  - Filenames with certain characters (e.g. " " or "'") will cause an error
#    if we try adding them as-is. We can work around this using builtins.path.
#  - Paths which reference things in the Nix store can cause errors when used
#    with functions like builtins.path.
#  - We can use builtins.unsafeDiscardStringContext to avoid errors, but we
#    must ensure that the context is added back in so that dependencies are
#    are built when needed and not garbage collected from under us.
{ asPath, hello, lib, runCommand, sanitiseName }:

with builtins;
with lib;
rec {
  def = p:
    with rec {
      strP = unsafeDiscardStringContext (toString p);

      # Checks whether a path is from the Nix store, since Nix will abort if
      # store paths are referenced in certain ways.
      isStore = x: hasPrefix storeDir (toString x);

      # Chops suffices off a store path until it's a top-level entry, e.g.
      #   getRoot "/nix/store/...-foo/bar/baz" -> "/nix/store/...-foo"
      # This way we're guaranteed to avoid filename characters which aren't
      # valid store paths.
      getRoot = x: if toString (dirOf x) == toString storeDir
                      then x
                      else getRoot (dirOf x);

      # Complements getRoot:
      #   p = "/nix/store/...-foo/bar/baz" -> trunk = "bar/baz"
      trunk = removePrefix "/" (removePrefix (getRoot strP) strP);

      # Avoids characters which are incompatible with store paths
      safeName = sanitiseName (baseNameOf strP);

      # For store paths, we make a symlink which depends on the root. This way
      # we can avoid incompatible characters (since the root must be safe, by
      # definition of it being a store path) without using builtins.path (which
      # Nix complains about if we give it a store path)
      symlink = runCommand safeName
        {
          inherit trunk;
          root = asPath (getRoot p);
        }
        ''
          if [[ -z "$trunk" ]]
          then
            ln -s "$root" "$out"
          else
            ln -s "$root/$trunk" "$out"
          fi
        '';
    };
    if isStore p
       then trace "Symlink for ${toString p}" symlink
       else trace "Path for ${toString p}" builtins.path { name = safeName; path = p; };

  tests = {
    self       = def ./addPathToStore.nix;
    dir        = def ./.;
    dirEntry   = def (./. + "/addPathToStore.nix");
    dodgyName  = def (./. + "/attrsToDirs'.nix");
    storePath  = def "${hello}";
    storeEntry = def "${hello}/bin/hello";
    dodgyStore = def "${./.}/attrsToDirs'.nix";
  };
}
