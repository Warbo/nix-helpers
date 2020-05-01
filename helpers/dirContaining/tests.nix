{ dirContaining, runCommand }:

with {
  data = runCommand "dirContaining-test-data" {} ''
      mkdir -p "$out/foo"
      echo "baz" > "$out/foo/bar"
    '';
};
dirContaining data [ "${data}/foo/bar" ]
