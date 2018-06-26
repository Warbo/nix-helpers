{ attrsToDirs, withNix, wrap }:

with builtins;
with { nixy = withNix {}; };
attrsToDirs {
  bin = {
    inNixedDir = wrap {
      paths  = nixy.buildInputs;
      vars   = removeAttrs nixy [ "buildInputs" ];
      script = ''
        #!/usr/bin/env bash
        set -e

        # Runs the given command in a temporary directory, adds that directory
        # to the Nix store then deletes the temp directory. If a second argument
        # is given, it's used as the directory name (which Nix prefixes with a
        # content hash).

        NAME="nixed-dir"
        [[ -z "$2" ]] || NAME="$2"

        if [[ "$SKIP_NIX" -eq 1 ]]
        then
          INNER="$NAME"
        else
          SCRATCH=$(mktemp -d)
          trap "rm -rf $SCRATCH" EXIT
          INNER="$SCRATCH/$NAME"
        fi

        mkdir -p "$INNER"
        pushd "$INNER" > /dev/null
          "$1"
        popd           > /dev/null

        if [[ "$SKIP_NIX" -eq 1 ]]
        then
          readlink -f "$INNER"
        else
          nix-store --add "$INNER"
        fi
      '';
    };
  };
}
