{ fail, runCommand, withNix, writeScript }:

with {
  expr = ''import "${writeScript "withLatestGit-example.nix" ''
    with import ${./../..};
    withLatestGit {
      url      = "http://chriswarbo.net/git/nix-helpers.git";
      srcToPkg = x: x;
    }''}"'';
};
runCommand "test-withLatestGit"
  (withNix { buildInputs = [ fail ]; })
  ''
    echo "Checking if nix_git_rev_... is set inside nix-shell" 1>&2
    CODE=0
    OUTPUT=$(nix-shell --show-trace -E '${expr}' --run 'env') ||
      fail "Failed to run nix-shell: $OUTPUT"

    echo "$OUTPUT" | grep "^nix_git_rev_" > /dev/null ||
      fail "No nix_git_rev_... variables were set: $OUTPUT"

    echo "Shell environment contained nix_git_rev_... variable" 1>&2

    echo "Running nested nix-shells" 1>&2
    CODE=0
    OUTPUT=$(nix-shell --show-trace -E '${expr}' --run \
      'nix-shell --show-trace -E '"'"'${expr}'"'"' --run true' 2>&1) ||
      fail "Nested shells failed: $OUTPUT"

    echo "$OUTPUT" 1>&2

    echo "Making sure we only checked git repos at most once" 1>&2
    SEEN=""
    while read -r LINE
    do
      URL=$(echo "$LINE" | sed -e 's/.*repo-head-//g' | grep -o '[a-z0-9]*')
      STAMP=$(echo "$LINE" | sed -e 's@.*store/@@g' | sed -e 's@-repo-head-.*@@g')
      ENTRY=$(echo -e "$URL\t$STAMP")
      while read -r STAMPS
      do
        FST=$(echo "$STAMPS" | cut -f2)
        SND=$(echo "$STAMPS" | cut -f3)
        [[ "x$FST" = "x$SND" ]] && fail "Multiple timestamps for '$URL'"
      done < <(join <(echo "$SEEN") <(echo "$ENTRY"))
      SEEN=$(echo "$SEEN"; echo "$ENTRY")
    done < <(echo "$OUTPUT" | grep "^building.*repo-head")

    echo "Looks OK" 1>&2
    echo "pass" > "$out"
  ''
