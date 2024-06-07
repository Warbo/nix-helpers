{ runCommand, unlines }:

runCommand "test-unlines"
  {
    x = unlines [
      "foo"
      "bar"
    ];
  }
  ''
    echo pass > "$out"
  ''
