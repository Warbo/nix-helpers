{ runCommand }:

with rec {
  f = builtins.concatStringsSep "\n";
};
{
  pkg   = f;
  tests = [
    (runCommand "test-unlines"
      { x = f [ "foo" "bar" ]; }
      ''
        echo pass > "$out"
      '')
  ];
}
