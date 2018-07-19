{ cabal-install, cabalField, dropWhile, fail, hackageDb, haskell, jq, lib,
  nixListToBashArray, nixpkgs1703, reverse, runCommand, stringAsList, utillinux,
  writeScript }:

with lib;

{
  def = {
    delay-failure   ? false,  # Replace eval failures with failing derivation
    dir,
    extra-sources   ? [],
    hackageContents ? hackageDb,
    name            ? "pkg",
    ghc,
    skipPackages    ? [ "base" "bin-package-db" "ghc" "rts" ]
  }:

  with rec {
    inherit (nixListToBashArray {
              name = "extraSources";
              args = extra-sources;
            })
            env code;

    deps = import depsDrv;

    # Keep this as a standalone derivation, rather than importing it directly,
    # so that we can add it as a dependency of our outputs. That way it won't
    # get garbage collected until our outputs are.
    depsDrv = runCommand "haskell-${name}-deps"
      (env // {
        inherit dir hackageContents;
        buildInputs  = [ cabal-install fail ghc jq utillinux ];
        delayFailure = if delay-failure then "true" else "false";
        failFile     = writeScript "delayed-failure.nix" ''
          with builtins;
          {
            delayedFailure = true;
            stderr         = readFile ./ERR;
          }
        '';
      })
      ''
        set -e
        set -o pipefail

        cp -r "$dir" ./src
        chmod +w -R  ./src

        export HOME="$PWD/home"
        mkdir "$HOME"
        cp -rv "$hackageContents/.cabal" "$HOME/"
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

        cabal new-freeze 2> >(tee ERR 1>&2) || {
          if "$delayFailure"
          then
            mkdir "$out"
            cp ERR "$out/ERR"
            cp "$failFile" "$out/default.nix"
            exit 0
          else
            echo "Error freezing cabal dependencies" 1>&2
            exit 1
          fi
        }

        [[ -e cabal.project.freeze ]] || fail "No cabal.project.freeze file"

        echo '[' > "$out"
        while read -r P
        do
          # Remove "packages:" field name
          if echo "$P" | grep ':' > /dev/null
          then
            P=$(echo "$P" | cut -d ':' -f2)
          fi
          SKIP=0
          for SKIPPABLE in ${concatStringsSep " " skipPackages}
          do
            if echo "$P" | grep "^$SKIPPABLE-[0-9.]*" > /dev/null
            then
              echo "Skipping dependency '$P'" 1>&2
              SKIP=1
            fi
          done
          [[ "$SKIP" -eq 1 ]] && continue
          printf '"%s"\n' "$P" >> "$out"
        done < <(grep '==' < cabal.project.freeze | sed -e 's/==/-/g' |
                                                    tr -d ' '         |
                                                    tr -d ','         )
        echo ']' >> "$out"
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
    replacedDeps = map (dep: if hasAttr (removeVersion dep) extrasMap
                                then getAttr (removeVersion dep) extrasMap
                                else "cabal://${dep}")
                       deps;
  };
  {
    gcRoots = [ depsDrv ];
    deps    = if deps.delayedFailure or false
                 then deps
                 else replacedDeps ++ [ dir ];
  };

  tests = {};
}
