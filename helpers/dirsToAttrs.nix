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
{ attrsToDirs, die, isPath, lib, runCommand }:

with builtins;
with lib;
with rec {
  go = dir: mapAttrs (n: v: if v == "regular" || v == "symlink"
                               then dir + "/${n}"
                               else go (dir + "/${n}"))
                     (readDir dir);
};

# Check that we can access some known files/directories
with { test = go ./..; };
assert isAttrs test || die {
  error = "test isn't attrset";
  type  = typeOf test;
};
assert test ? helpers || die {
  error = "No 'helpers' in test";
  names = attrNames test;
};
assert isAttrs test.helpers || {
  error = "test.helpers isn't attrset";
  type  = typeOf test.helpers;
};
assert test.helpers ? "dirsToAttrs.nix" || {
  error = "No 'dirsToAttrs.nix' in test.helpers";
  names = attrNames test.helpers;
};
assert isPath test.helpers."dirsToAttrs.nix" || {
  error = "test.helpers.dirsToAttrs.nix isn't path";
  type  = typeOf test.helpers."dirsToAttrs.nix";
};

{
  def   = go;
  tests = runCommand "dirsToAttrs-test"
    (go (attrsToDirs { x = ./dirsToAttrs.nix; }))
    ''
      [[ -n "$x" ]]                      || exit 1
      [[ -f "$x" ]]                      || exit 2
      grep 'builtins' < "$x" > /dev/null || exit 3

      echo "pass" > "$out"
    '';
}
