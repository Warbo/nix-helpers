# Builds a directory whose entries/content correspond to the names/values of
# the given attrset. When a value is an attrset, the corresponding entry is
# a directory, whose contents is generated with attrsToDirs on that value.
{ addPathToStore, asPath, die, dummyBuild, foldAttrs', getType, hello, isPath,
  lib, nixListToBashArray, nothing, runCmd, runCommand, sanitiseName,
  writeScript }:

with builtins;
with lib;
with rec {
  # Traverses into the given nested attrset, producing a list of name/value
  # pairs, where each value is a path or derivation, and each name is the path
  # through the attrsets to reach that value. Values which are paths get copied
  # into the Nix store first.
  toPaths = prefix: val:
    if isPath val
       then [{ name = prefix; value = addPathToStore val; }]
       else if isDerivation val
               then [{ name = prefix; value = val; }]
               else if isAttrs val
                       then concatMap (entry: toPaths (prefix + "/" + entry)
                                                      (getAttr entry val))
                                      (attrNames val)
                       else die {
                         error   = "Unsupported type in attrsToDirs'";
                         given   = getType val;
                         allowed = [ "path" "derivation" "set" ];
                       };
};
rec {
  def = rawName: attrs:
    with rec {
      name = sanitiseName "${rawName}";

      # We can't have empty attr names, so always stick a dummy '_' at the start,
      # and strip it off in the build script
      data = listToAttrs (toPaths "_" attrs);

      # The element order of these lists is arbitrary, but they must match
      paths    = attrNames data;
      content  = map (n: getAttr n data) paths;

      # Create bash code and env vars for the build command, without forcing any
      # derivations to be built at eval time.
      pathData    = nixListToBashArray { name = "VALPATHS"; args = paths;   };
      contentData = nixListToBashArray { name = "VALUES";   args = content; };
    };
    if attrs == {}
       then dummyBuild name
       else runCmd name (pathData.env // contentData.env) ''
              ${pathData.code}
              ${contentData.code}

              # Loop over each path/content entry in our arrays (off-by-one cruft
              # is due to seq preferring to count from 1)
              for NPLUSONE in $(seq 1 "''${#VALUES[@]}")
              do
                N=$(( NPLUSONE - 1 ))

                # The output path we're going to make; cut off leading _ and
                # prepend $out
                STRIPPED=$(echo "''${VALPATHS[$N]}" | cut -c 2-)
                       P="$out$STRIPPED"

                # Ensure parent directories exist
                mkdir -p "$(dirname "$P")"

                # Link value in place (saves space compared to copying)
                ln -s "''${VALUES[$N]}" "$P"
              done
            '';
  tests = {
    # Our filename contains a "'" which means it isn't a valid Nix store path.
    # Make sure we can still include it.
    punctuated = def "attrsToDirsTest" {
      foo = { bar = ./. + "/attrsToDirs'.nix"; };
    };

    # Nix complains if strings refer to store paths, so check that we avoid this
    storePaths = def "storePathTest" {
      foo = { bar = "${hello}/bin/hello"; };
    };

    # Combine the above problems
    punctuatedStore = def "punctuatedStorePathTest" {
      foo = { bar = "${./.}/attrsToDirs'.nix"; };
    };

    # Check that dependencies of (strings of) paths become dependencies of the
    # resulting derivation.
    dependenciesPreserved =
      with rec {
        file1 = writeScript "test-file1" "content1";
        file2 = writeScript "test-file2" "content2";
        link1 = runCommand  "test-link1" { inherit file1; } ''
          mkdir "$out"
          ln -s "$file1" "$out/link1"
        '';
        link2 = runCommand  "test-link2" { inherit file2; } ''
          ln -s "$file2" "$out"
        '';
        dir   = def "dirsWithDeps" {
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
  };
}
