{ fail, replace, runCommand }:

with builtins;
with {
  test = { args, name, pre, post }:
    runCommand "replace-test-${name}" { buildInputs = [ replace fail ]; } ''
      ${pre}replace ${concatStringsSep " " args}${post}
      mkdir "$out"
    '';
}; {
  die-odd-args = test {
    name = "die-old-args";
    args = [ "old1" "new1" "unpaired" ];
    pre = "echo 'hello' | ";
    post = " && fail 'Should have died on odd args'";
  };
  replace-single-inplace = test {
    name = "single-stdin";
    args = [ "old" "new" "--" "f" ];
    pre = ''
      echo "embolden" > f

    '';
    post = ''

      X=$(cat f)
      [[ "x$X" = "xembnewen" ]] || fail "Didn't replace, got:$X"
    '';
  };
  replace-two-stdin = test {
    name = "two-stdin";
    args = [ "foo" "bar" "baz" "quux" ];
    pre = ''
      X=$(echo -e 'fools are barred
      from bazinga' | '';
    post = ''
      )
      Y=$(echo -e 'barls are barred\nfrom quuxinga')
      [[ "x$X" = "x$Y" ]] || fail "No match:\n$X\n\n$Y"
    '';
  };
}
