{ runCommand }:

rec {
  def   = prefer: fallback: if (builtins.tryEval prefer).success
                               then prefer
                               else fallback;
  tests = runCommand "test-tryElse" { x = def <nope> "fallback"; } ''
    echo pass > "$out"
  '';
}
