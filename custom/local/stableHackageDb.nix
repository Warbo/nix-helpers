{ stableHackage, runCommand }:

runCommand "stable-hackage-db" { buildInputs = [ stableHackage ]; } ''
  mkdir -p "$out"
  HOME="$out" makeCabalConfig
''
