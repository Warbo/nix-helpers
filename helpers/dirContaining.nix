# Create a directory containing 'files'; the directory structure will be
# relative to 'base', for example:
#
#   dirContaining /foo/bar [ /foo/bar/baz /foo/bar/quux/foobar ]
#
# Will produce a directory containing 'baz' and 'quux/foobar'.
{ mergeDirs, runCommand }:

with builtins;
rec {
  pkg = base: files:
    mergeDirs (map (f: runCommand "dir"
                         {
                           base = toString base;
                           file = toString base + "/${f}";
                         }
                         ''
                           REL=$(echo "$file" | sed -e "s@$base/@@g")
                           DIR=$(dirname "$REL")
                           mkdir -p "$out/$DIR"
                           ln -s "$file" "$out/$REL"
                         '')
                   files);
  tests = pkg ../local [ ../local/dirContaining.nix ];
}
