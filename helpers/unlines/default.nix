{ runCommand }:

with rec {
  f = builtins.concatStringsSep "\n";
};
{
  def   = f;
  tests = runCommand "test-unlines" { x = f [ "foo" "bar" ]; } ''
    echo pass > "$out"
  '';
}
