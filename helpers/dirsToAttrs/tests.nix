{
  attrsToDirs',
  dirsToAttrs,
  runCommand,
}:

runCommand "dirsToAttrs-test"
  (dirsToAttrs (attrsToDirs' "dirsToAttrs-test-dir" { x = ./default.nix; }))
  ''
    [[ -n "$x" ]]                      || exit 1
    [[ -f "$x" ]]                      || exit 2
    grep 'builtins' < "$x" > /dev/null || exit 3

    echo "pass" > "$out"
  ''
