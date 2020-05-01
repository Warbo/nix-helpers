{ runCommand, tryElse }:

runCommand "test-tryElse" { x = tryElse <nope> "fallback"; } ''
  echo pass > "$out"
''
