{ bash, fail, hackageDb, mkBin, replace, rsync }:

mkBin {
  name   = "installHackage";
  paths  = [ bash fail replace rsync ];
  vars   = { inherit hackageDb; };
  script = ''
    #!/usr/bin/env bash
    set -e

    # Ensure HOME exists, since we don't want to accidentally create
    # /homeless-shelter
    [[ -d "$HOME" ]] || fail "HOME dir '$HOME' isn't directory, aborting"

    # Ensure .cabal doesn't exist, since we don't want to e.g. overwrite stuff
    # in actual /home directories
    [[ -d "$HOME/.cabal" ]] && fail "Found .cabal dir in '$HOME', aborting"

    # Put files in place, except for large tarballs
    rsync --progress -r --exclude='01-index.tar*' "$hackageDb/.cabal" "$HOME/"

    # Update all self-references to the new location
    chmod +w -R "$HOME"
    find "$HOME/.cabal" -type f | while read -r F
    do
      replace "$hackageDb" "$HOME" -- "$F"
    done

    # Symlink large tarballs in place
    find "$hackageDb/.cabal" -type f -name '01-index.tar*' | while read -r F
    do
      DEST=$(echo "$F" | replace "$hackageDb" "$HOME")
      ln -s "$F" "$DEST"
    done

    echo "Installed '$hackageDb' to '$HOME/.cabal'" 1>&2
  '';
}
