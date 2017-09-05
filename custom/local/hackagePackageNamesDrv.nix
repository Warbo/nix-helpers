{ stableHackage, runCommand }:

runCommand "hackage-package-names"
  {
    inherit stableHackage;
  }
  ''
    tar tf "$stableHackage/00-index.tar" | grep -o '^[^/]*' | sort -u > "$out"
  ''
