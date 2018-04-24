{ cabal2nix, cabal2nixCache, cabalField, fail, ghc, haskellPackages, jq, nix,
  nixpkgs1603, runCommand, stableHackage, unpack, utillinux, withDeps,
  withNix }:

with rec {
  go = {
    cabal-args ? [ "--enable-tests" "--enable-benchmarks" ],
    dir,
    name ? null
  }:
    with {
      pName = if name == null
                 then cabalField { inherit dir; field = "name"; }
                 else name;
      args = builtins.concatStringsSep " " cabal-args;
    };
    runCommand "haskell-expr-${pName}"
      (withNix {
        inherit cabal2nixCache dir pName;
        buildInputs = [ cabal2nix fail ghc jq nix stableHackage utillinux ];
      })
      ''
        export HOME="$PWD/home"
        mkdir "$HOME"
        makeCabalConfig

        cp -r "$dir" "$PWD/src"
        chmod +w -R "$PWD/src"
        pushd "$PWD/src" 1>&2
          [[ -e .cabal-sandbox ]] && rm -rf .cabal-sandbox
          cabal sandbox init

          # The --reorder-goals option enables heuristics which make cabal more
          # likely to succeed. It's off by default since it's slower.
          GOT=$(cabal install --dry-run \
                              --reorder-goals ${args} 2> >(tee ERR)) || {
            echo "$GOT" 1>&2
            [[ -e ERR ]] && cat ERR 1>&2
            fail "Error listing cabal dependencies"
            exit 1
          }
          echo "$GOT"
        popd 1>&2

        MSG='the following would be installed'
        L=$(echo "$GOT" | grep -A 9999999 "$MSG" | tail -n+2) || {
          echo "$GOT" 1>&2
          [[ -e ERR ]] && cat ERR 1>&2
          fail "Didn't spot a build plan"
          exit 1
        }

        function getNames {
          rev | cut -d '-' -f 2- | rev
        }

        mkdir "$out"
        echo '['                            >  "$out/default.nix"
          echo "$L" | getNames | jq -R '.' >> "$out/default.nix"
        echo ']'                           >> "$out/default.nix"

        mkdir -p "$out/pkgs"

        # Awk will dedupe the dependencies (e.g. 'foo-1 (lib)\nfoo-1 (test)...')
        echo "$L" | awk '!a[$0]++' | while read -r PKG
        do
          NAME=$(echo "$PKG" | getNames)
          if [[ "x$NAME" = "x$pName" ]]
          then
            echo "Running cabal2nix on $dir" 1>&2
            cabal2nix "$dir" > "$out/pkgs/$NAME.nix"
          else
                DEST="$out/pkgs/$NAME.nix"
              SHASUM="$cabal2nixCache/hashes/$PKG.sha256"
            EXISTING="$cabal2nixCache/exprs/$PKG.nix"

            if [[ -e "$EXISTING" ]]
            then
              cp -v "$EXISTING" "$DEST"
            else
              echo "Running cabal2nix on $PKG" 1>&2
              if [[ -e "$SHASUM" ]]
              then
                SHA256=$(cat "$SHASUM")
                cabal2nix --sha256 "$SHA256" "cabal://$PKG" > "$DEST"
              else
                cabal2nix                    "cabal://$PKG" > "$DEST"
              fi

              if [[ -e "$cabal2nixCache" ]]
              then
                echo "Storing in cabal2nix cache ($cabal2nixCache)" 1>&2
                cp -v "$DEST" "$EXISTING" &&
                chmod 777     "$EXISTING" || echo "Failed to cache" 1>&2

                HOMESUM="$HOME/.cache/cabal2nix/$PKG.sha256"
                if [[ -e "$HOMESUM" ]]
                then
                  [[ -e "$SHASUM" ]] || {
                    cp -v "$HOMESUM" "$SHASUM" &&
                    chmod 777        "$SHASUM" || echo "Failed to cache" 1>&2
                  }
                fi
              fi
            fi
          fi
        done
      '';

  test = go {
    cabal-args = [];
    dir        = unpack haskellPackages.text.src;
    name       = "text";
  };
};

args: withDeps [ (test // { name = "haskellPkgDepsDrv-test"; }) ]
               (go args)
