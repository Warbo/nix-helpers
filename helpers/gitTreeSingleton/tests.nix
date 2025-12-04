{
  dash,
  diffutils,
  git,
  gitTreeSingleton,
  qpdf,
  runCommand,
}:

with {
  test =
    name:
    runCommand "gitTreeSingleton-test-${name}" {
      buildInputs = [
        git
        qpdf
      ];
    };
};
{
  valid-git-object = test {
    name = "valid-git-object";
    script = ''
      set -u
      git init -q
      tree=${
        gitTreeSingleton {
          name = "test";
          sha1 = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391";
        }
      }
      sha=$(sha1sum "$tree" | cut -d' ' -f1)
      obj_dir=".git/objects/$(echo "$sha" | cut -c1-2)"
      obj_file="$obj_dir/$(echo "$sha" | cut -c3- | tr -d '\n')"
      mkdir -p "$obj_dir"
      zlib-flate -compress < "$tree" > "$obj_file"
      type=$(git cat-file -t "$sha")
      [[ "$type" == "tree" ]] || {
        echo "Expected 'tree', got '$type'"
        exit 1
      } 1>&2
      mkdir "$out"
    '';
  };

  bash-matches-dash =
    runCommand "gitTreeSingleton-test-bash-matches-dash"
      {
        buildInputs = [
          dash
          diffutils
        ];
        builderScript =
          builtins.head
            (gitTreeSingleton {
              name = "hallo-file";
              sha1 = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391";
            }).args;
      }
      ''
        set -u
        out="bash-result" bash "$builderScript"
        out="dash-result" dash "$builderScript"
        cmp "bash-result" "dash-result"
        mkdir $out
      '';
}
