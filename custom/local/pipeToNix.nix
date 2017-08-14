{ attrsToDirs, withNix, wrap }:

with builtins;
with { nixy = withNix {}; };

attrsToDirs {
  bin = {
    pipeToNix = wrap {
      name   = "pipeToNix";
      paths  = nixy.buildInputs;
      vars   = removeAttrs nixy [ "buildInputs" ];
      script = ''
        #!/usr/bin/env bash
        set -e

        # Dumps stdin to a temporary file, adds that file to the Nix store then
        # deletes the temp file. If an argument is given, it's used as the file
        # name (which Nix will prefix with a content hash).

        NAME="piped"
        [[ -z "$1" ]] || NAME="$1"

        SCRATCH=$(mktemp -d)
        trap "rm -rf $SCRATCH" EXIT

        F="$SCRATCH/$NAME"
        cat > "$F"

        nix-store --add "$F"
      '';
    };
  };
}
