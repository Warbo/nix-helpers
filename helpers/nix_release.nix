# Evaluate and/or build all derivations in a release.nix file
{ attrsToDirs', bash, fail, repo1809, withNix, wrap }:

with rec {
  paths = (withNix {}).buildInputs ++ [ bash fail ];

  nix_release_eval = wrap {
    inherit paths;
    name = "nix_release_eval";
    vars = withNix {
      attrs = ''
        (with import ${repo1809} {
          config   = {};
          overlays = [ (import "${./..}/overlay.nix") ];
        };
        drvPathsIn (import ./release.nix))
      '';
    };
    script = ''
      #!${bash}/bin/bash
      set -e

      [[ -e release.nix ]] || fail "No release.nix found, aborting"

      echo "Finding derivations" 1>&2
      nix eval --show-trace --raw "$attrs"
    '';
  };

  nix_release = wrap {
    name   = "nix_release";
    paths  = [ bash fail ];
    vars   = { inherit nix_release_eval; };
    script = ''
      #!${bash}/bin/bash
      set -e

      DRVPATHS=$("$nix_release_eval") ||  fail "Failed to get paths, aborting"

      function build {
          nix-store --show-trace --realise "$@"
      }

      echo "Building derivations" 1>&2
      COUNT=0
      FAILS=0
      while read -r PAIR
      do
        COUNT=$(( COUNT + 1 ))
        ATTR=$(echo "$PAIR" | cut -f1)
         DRV=$(echo "$PAIR" | cut -f2)

        echo "Building $ATTR" 1>&2
        if [[ -z "$ADD_ROOT" ]]
        then
            build                                   "$@" "$DRV" ||
                FAILS=$(( FAILS + 1 ))
        else
            build --indirect --add-root "$ADD_ROOT" "$@" "$DRV" ||
                FAILS=$(( FAILS + 1 ))
        fi
      done < <(echo "$DRVPATHS")

      if [[ "$FAILS" -eq 0 ]]
      then
        echo "All $COUNT built successfully" 1>&2
      else
        printf '%s/%s builds failed\n' "$FAILS" "$COUNT" 1>&2
        exit 1
      fi
    '';
  };
};
{
  def = attrsToDirs' "nix_release" {
    bin = { inherit nix_release nix_release_eval; };
  };

  tests = {};
}
