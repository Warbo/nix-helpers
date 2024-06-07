{
  bash,
  hasBinary,
  mkBin,
  nix,
  withDeps,
}:

with builtins;
with rec {
  got = builtins.getEnv "NIX_PATH";

  pkg = mkBin {
    name = "pipeToNix";
    paths = [ nix.out ];
    vars.NIX_PATH = if got == "" then "nixpkgs=${<nixpkgs>}" else got;
    script = ''
      #!${bash}/bin/bash
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
withDeps [ (hasBinary pkg "pipeToNix") ] pkg
