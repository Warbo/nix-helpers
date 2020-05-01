{ runCommand, stringAsList }:

runCommand "stringAsList-test" { x = stringAsList (x: x) "hi"; } ''
  echo pass > "$out"
''
