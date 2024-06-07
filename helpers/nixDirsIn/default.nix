# Takes a directory path, returns any immediate children in that directory which
# are themselves directories, and contain a file with the given name
# ('default.nix' by default). Result is an attrset where names are the
# subdirectory names, e.g. "subdir", and values are full paths to the contained
# file, e.g. "${dir}/subdir/default.nix".
#
# Note that this is used to bootstrap nix-helpers, so it should work standalone.
{ }:

{
  dir,
  filename ? "default.nix",
}:
with rec {
  inherit (builtins)
    attrNames
    filter
    getAttr
    hasAttr
    listToAttrs
    readDir
    ;

  subdirs = filter hasFile (attrNames entries);

  entries = readDir dir;

  hasFile =
    name:
    (getAttr name entries == "directory")
    && (hasAttr filename (readDir (dir + "/${name}")));

  output = name: {
    inherit name;
    value = dir + "/${name}/${filename}";
  };
};
listToAttrs (map output subdirs)
