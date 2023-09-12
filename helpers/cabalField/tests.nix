{ cabalField, nixpkgs1803, runCommand, unpack' }:

runCommand "cabalField-test" {
  found = cabalField {
    dir = unpack' "text" nixpkgs1803.haskellPackages.text.src;
    field = "name";
  };
} ''
  [[ "x$found" = "xtext" ]] || {
    echo "Got '$found' instead of 'text'" 1>&2
    exit 1
  }
  mkdir "$out"
''
