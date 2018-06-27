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
with {
  test = go (runCommand "dirsToAttrs-test-data" {} ''
    mkdir -p "$out/foo"
    echo "baz" > "$out/foo/bar"
  '');
};
assert isAttrs test || die {
  error = "test isn't attrset";
  type  = typeOf test;
};
assert test ? foo || die {
  error = "No 'foo' in test";
  names = attrNames test;
};
assert isAttrs test.foo || {
  error = "test.foo isn't attrset";
  type  = typeOf test.foo;
};
assert test.foo ? bar || {
  error = "No 'bar' in test.foo";
  names = attrNames test.foo;
};
assert isPath test.foo.bar || {
  error = "test.foo.bar isn't path";
  type  = typeOf test.foo.bar;
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
