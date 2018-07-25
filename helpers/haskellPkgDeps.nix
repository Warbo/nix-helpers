{ cabal-install, cabalField, dropWhile, fail, hackageDb, haskell, jq, lib,
  nixListToBashArray, nixpkgs1703, reverse, runCommand, stringAsList, utillinux,
  writeScript }:

with lib;

{
  def = {
    dir,
    extra-sources   ? [],
    hackageContents ? hackageDb,
    name            ? "pkg",
    ghc
  }:

  with rec {
    inherit (nixListToBashArray {
              name = "extraSources";
              args = extra-sources;
            })
            env code;

    # If a package is "pre-existing", we can't build it (e.g. rts, base, ...)
    deps = filter ({ type, ... }: type != "pre-existing")
                  (import depsDrv);

    # Keep this as a standalone derivation, rather than importing it directly,
    # so that we can add it as a dependency of our outputs. That way it won't
    # get garbage collected until our outputs are.
    depsDrv = runCommand "haskell-${name}-plan"
      (env // {
        inherit dir hackageContents;
        buildInputs = [ cabal-install fail ghc jq utillinux ];
        EXPR = "with builtins; fromJSON (readFile ./plan.json)";
        JQ   = ''.["install-plan"] | map({"name"    : .["pkg-name"],
                                          "version" : .["pkg-version"],
                                          "type"    : .["type"]})'';
      })
      ''
        set -e
        set -o pipefail

        cp -r "$dir" ./src
        chmod +w -R  ./src

        export HOME="$PWD/home"
        mkdir "$HOME"
        cp -rsv "$hackageContents/.cabal" "$HOME/"
        chmod +w -R "$HOME/.cabal"

        cd ./src

        ${code}
        PACKAGES=""
        for VAL in "''${extraSources[@]}"
        do
          if [[ -z "$PACKAGES" ]]
          then
            PACKAGES="packages: $VAL"
          else
            PACKAGES="$PACKAGES, $VAL"
          fi
        done
        [[ -z "$PACKAGES" ]] || {
          echo -e "Adding extra sources to cabal.project.local:\n$PACKAGES" 1>&2
          echo "$PACKAGES" > cabal.project.local
        }

        cabal new-build --dry || {
          echo "Error dry-running build" 1>&2
          exit 1
        }

        mkdir "$out"
        jq "$JQ" < ./dist-newstyle/cache/plan.json > "$out/plan.json"
        echo "$EXPR" > "$out/default.nix"
      '';

    extrasMap = listToAttrs (map (dir: {
                                   name = cabalField {
                                     inherit dir;
                                     field = "name";
                                   };
                                   value = dir;
                                 })
                                 extra-sources);

    # Takes 'foo-bar-1.2.3' and returns 'foo-bar'
    removeVersion =
      stringAsList
        (chars: if elem "-" chars
                   then reverse                           # Restore order
                          (tail                           # Drop '-'
                            (dropWhile (c: c != "-")      # Drop up to '-'
                                       (reverse chars)))  # Start at end
                   else chars);

    # If a dependency comes from extra-sources, use its path; otherwise prefix
    # with "cabal://" so cabal2nix will fetch from Hackage.
    replacedDeps = map ({ name, version, ... }:
                         extrasMap."${name}" or "cabal://${name}-${version}")
                       deps;
  };
  {
    gcRoots = [ depsDrv ];
    deps    = replacedDeps ++ [ dir ];
  };

  tests = {};
}
