{ runCommand }:

rec {
  pkg   = prefer: fallback: if (builtins.tryEval prefer).success
                               then prefer
                               else fallback;
  tests = [
    (runCommand "test-tryElse" { x = pkg <nope> "fallback"; } ''
      echo pass > "$out"
    '')
  ];
}
