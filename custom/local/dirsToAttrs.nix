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
{ lib }:

with builtins;
with lib;

dir: mapAttrs (n: v: if v == "regular"
                        then dir + "/${n}"
                        else dirsToAttrs (dir + "/${n}"))
              (readDir dir)
