# Read the contents of a directory, building up an attrset of the paths. For
# example, given:
#
#   foo/
#     bar.html
#     baz/
#       quux.mp3
#
# We will get:
#
#   {
#     foo = {
#       "bar.html" = /path/to/foo/bar.html;
#       baz        = {
#         "quux.mp3" = /path/to/foo/baz/quux.mp3;
#       };
#     };
#
{ attrsToDirs, isPath, lib, runCommand }:

with builtins;
with lib;

with rec {
  go = dir: mapAttrs (n: v: if v == "regular" || v == "symlink"
                               then dir + "/${n}"
                               else go (dir + "/${n}"))
                     (readDir dir);

  # Check that we can access some known files/directories
  test =
    with {
      x = go ./..;
    };
    isAttrs x       &&
    x ? local       &&
    isAttrs x.local &&
    x.local ? "dirsToAttrs.nix" &&
    isPath x.local."dirsToAttrs.nix";
};

assert test;
{
  pkg   = go;
  tests = runCommand "dirsToAttrs-test"
    (go (attrsToDirs { x = ./dirsToAttrs.nix; }))
    ''
      [[ -n "$x" ]]                      || exit 1
      [[ -f "$x" ]]                      || exit 2
      grep 'builtins' < "$x" > /dev/null || exit 3

      echo "pass" > "$out"
    '';
}
