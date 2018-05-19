{}:

with rec {
  f = prefer: fallback: if (builtins.tryEval prefer).success
                           then prefer
                           else fallback;
};
{
  pkg   = f;
  tests = [
    (runCommand "test-tryElse"
      { x = tryElse <nope> "fallback"; }
      ''
        echo pass > "$out"
      '')
  ];
}
