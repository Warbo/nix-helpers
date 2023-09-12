{ attrsToDirs', hello, runCommand, writeScript }:

{
  # Our filename contains a "'" which means it isn't a valid Nix store path.
  # Make sure we can still include it.
  punctuated = attrsToDirs' "attrsToDirsTest" {
    foo = { bar = ./.. + "/attrsToDirs'/default.nix"; };
  };

  # Nix complains if strings refer to store paths, so check that we avoid this
  storePaths =
    attrsToDirs' "storePathTest" { foo = { bar = "${hello}/bin/hello"; }; };

  # Combine the above problems
  punctuatedStore = attrsToDirs' "punctuatedStorePathTest" {
    foo = { bar = "${./..}/attrsToDirs'/default.nix"; };
  };

  # Check that dependencies of (strings of) paths become dependencies of the
  # resulting derivation.
  dependenciesPreserved = with rec {
    file1 = writeScript "test-file1" "content1";
    file2 = writeScript "test-file2" "content2";
    link1 = runCommand "test-link1" { inherit file1; } ''
      mkdir "$out"
      ln -s "$file1" "$out/link1"
    '';
    link2 = runCommand "test-link2" { inherit file2; } ''
      ln -s "$file2" "$out"
    '';
    dir = attrsToDirs' "dirsWithDeps" {
      entry1 = "${link1}/link1";
      entry2 = "${link2}";
    };
  };
    runCommand "dependenciesPreservedTest" { inherit dir; } ''
      function fail {
        echo "$*" 1>&2
        exit 1
      }

      [[ -d "$dir"        ]] || fail "No such directory '$dir'"
      [[ -e "$dir"/entry1 ]] || fail "No entry1 in '$dir'"
      [[ -e "$dir"/entry2 ]] || fail "No entry2 in '$dir'"

      file1=$(readlink -f "$dir"/entry1)
      file2=$(readlink -f "$dir"/entry2)

      [[ -e "$file1" ]] || fail "Destination '$file1' not found"
      [[ -e "$file2" ]] || fail "Destination '$file2' not found"

      grep 'content1' < "$file1" > /dev/null || fail "No content in '$file1'"
      grep 'content2' < "$file2" > /dev/null || fail "No content in '$file2'"

      mkdir "$out"
    '';
}
