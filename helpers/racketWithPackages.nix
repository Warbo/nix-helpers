{ fail, fetchFromGitHub, hasBinary, makeWrapper, nixpkgs1609, nixpkgsRelease,
  path, racket, runCommand, withNix }:

with builtins;
rec {
  racketWorks = currentSystem != "i686-linux" ||
                compareVersions nixpkgsRelease "1703" == -1;

  racketPkg = if racketWorks
                 then racket
                 else trace ''WARNING: Taking racket from nixpkgs 16.09, since
                              it's broken on i686 for newer versions''
                            nixpkgs1609.racket;

  def = deps: runCommand "racket-with-deps"
    {
      inherit deps racketPkg;
      buildInputs  = [ makeWrapper racketPkg ];
    }
    ''
      # raco writes to HOME, so make sure that's included
      export HOME="$out/etc"
      mkdir -p "$HOME"

      # Each PKG should be a directory (e.g. pulled from git) containing
      # "collections" as sub-directories. For example if PKG should allow
      # (require utils/printing), it should contain PKG/utils/printing.rkt

      # Collect up all packages
      mkdir -p "$out/share/pkgs"
      for PKG in $deps
      do
        cp -r "$PKG" "$out/share/pkgs/"
      done

      # Make our copies mutable, so we can compile them in-place
      chmod +w -R "$out/share/pkgs"

      # Register packages with raco
      for PKG in "$out/share/pkgs/"*
      do
        # raco is Racket's package manager, -D says "treat as a directory of
        # collections", which is how git repos seem to be arranged.
        raco link --user -D "$PKG"
      done

      # Compile registered packages
      raco setup --avoid-main -x -D

      # Provide Racket binaries patched to use our modified HOME
      mkdir -p "$out/bin"
      for PROG in "$racketPkg"/bin/*
      do
        NAME=$(basename "$PROG")
        makeWrapper "$PROG" "$out/bin/$NAME" --set HOME "$out/etc"
      done
    '';

  tests =
    with {
      result = def [
        # Dependency of grommet
        (fetchFromGitHub {
          owner  = "RayRacine";
          repo   = "grip";
          rev    = "ec498f6";
          sha256 = "06ax30r70sz2hq0dzyassczcdkpmcd4p62zx0jwgc2zp3v0wl89l";
        })

        # Hashing
        (fetchFromGitHub {
          owner  = "RayRacine";
          repo   = "grommet";
          rev    = "50f1b6a";
          sha256 = "1rb7i8jx7gg2rm5flnql0hja4ph11p7i38ryxd04yqw50l0xj59v";
        })

        # Shell commands
        (fetchFromGitHub {
          owner  = "willghatch";
          repo   = "racket-shell-pipeline";
          rev    = "7ed9a75";
          sha256 = "06z5bhmvpdhy4bakh30fzha4s0xp2arjq8h9cyi65b1y18cd148x";
        })
      ];

      # If we're on a system we think has a broken racket, we should check to
      # make sure it actually is. If broken packages weren't so strict we could
      # take a look at racket.meta.broken, but we can't since it may cause Nix
      # to abort. Instead we define a test, which invokes Nix to do the check
      # and see if it succeeds. This is complicated by two things:
      #
      #  - We need to run Nix inside a builder. withNix lets us do this.
      #  - We need to ensure we're checking the version of nixpkgs that's called
      #    us, which might not be <nixpkgs>. We use the 'path' attribute of
      #    nixpkgs for this.
      checkWhetherBroken = if racketWorks then {} else {
        racket-override-still-needed = runCommand
          "racket-override-still-needed-for-nixpkgs${nixpkgsRelease}"
          (withNix { buildInputs = [ fail ]; })
          ''
            echo "Checking whether Racket in nixpkgs${nixpkgsRelease}," 1>&2
            echo "from ${path}, is still broken on ${currentSystem}."   1>&2
            KNOWN=0
            BROKEN=0

            function go {
              if [[ "$KNOWN" -eq 1 ]]
              then
                echo "Skipping '$1' since we know the result" 1>&2
                return
              fi
              echo "Checking '$1'" 1>&2
              nix-instantiate --eval -E \
                "with builtins // { pkgs = import \"${path}\" {}; }; $1"
            }

            # Check that we can actually look up packages, etc. None of these
            # should trigger a 'package marked as broken' message.

            X=$(go 'abort "Checking abort triggers error"' 2>&1) &&
              fail "'abort' didn't abort:\n$X"

            X=$(go 'true'                       2>&1) ||
              fail "'true' failed:\n$X"
            X=$(go 'pkgs ? bash   || abort "x"' 2>&1) ||
              fail "Couldn't find bash:\n$X"
            X=$(go 'pkgs ? racket || abort "x"' 2>&1) ||
              fail "Couldn't find racket:\n$X"
            X=$(go 'pkgs.racket ? meta || abort "No racket.meta"' 2>&1) ||
              fail "Couldn't find racket.meta:\n$X"

            # Now we try to check whether racket is broken. We need to
            # distinguish between true/false booleans and aborted evaluation.

            X=$(go 'let x = typeOf pkgs.racket.meta; in x == x' 2>&1) || {
              echo "Evaling racket.meta aborted:\n$X\Looks broken to me" 1>&2
              KNOWN=1
              BROKEN=1
            }

            X=$(go 'pkgs.racket.meta ? broken' 2>&1) || {
              echo "Evaling meta.broken aborted:\n$X\nLooks broken to me" 1>&2
              KNOWN=1
              BROKEN=1
            }

            if [[ "$KNOWN" -eq 0 ]] &&
               X=$(go 'pkgs.racket.meta ? broken && abort "No broken"' 2>&1)
            then
              echo "Can eval 'racket.meta' and it has no 'broken'" 1>&2
              KNOWN=1
              BROKEN=0
            fi

            X=$(go 'pkgs.racket.meta.broken' 2>&1) || {
              echo "Evaling meta.broken aborted:\n$X\nLooks broken to me" 1>&2
              KNOWN=1
              BROKEN=1
            }

            if [[ "$KNOWN" -eq 0 ]]
            then
              if X=$(go 'pkgs.racket.meta.broken && abort "Broken"' 2>&1)
              then
                echo "pkgs.racket.meta.broken is true" 1>&2
                KNOWN=1
                BROKEN=1
              else
                echo "pkgs.racket.meta.broken is false" 1>&2
                KNOWN=1
                BROKEN=1
              fi
            fi

            [[ "$KNOWN" -eq 1 ]] || fail "Couldn't tell if broken"

            # Subsequent nixpkgs versions avoid 'broken' in favour of checking
            # the 'platforms', so we try checking that
            if [[ "$BROKEN" -eq 0 ]]
            then
              echo "Racket is apparently not broken; checking platforms" 1>&2
              KNOWN=0
              X=$(go 'pkgs.racket.meta ? platforms' 2>&1) ||
                fail "Evaling meta.platforms aborted:\n$X"
              if X=$(go 'pkgs.racket.meta ? platforms || abort "None"' 2>&1)
              then
                X=$(go 'elem currentSystem pkgs.racket.meta.platforms ||
                        abort "currentSystem not in platforms"' 2>&1) || {
                  echo "Current system not in Racket's supported platforms" 1>&2
                  KNOWN=1
                  BROKEN=1
                }
              fi
            fi

            [[ "$KNOWN" -eq 1 ]] || fail "Still couldn't tell if broken"

            if [[ "$BROKEN" -eq 0 ]]
            then
              echo "Racket is apparently not broken; checking if it evals" 1>&2
              X=$(nix-instantiate -E '(import "${path}" {}).racket' 2>&1) ||
                fail "Racket is broken:\n$X\nOur checks failed to spot it"

              # If it's fixed, we'll need to redefine racketWorks
              fail "Racket doesn't seem to be broken. Maybe it's fixed?" 1>&2
            fi

            echo "Checking that racket truly is broken" 1>&2
            X=$(nix-instantiate -E '(import "${path}" {}).racket' 2>&1) &&
              fail "Our checks said Racket is broken, but it worked"
            echo "Yes, we thought racket was broken and it is." 1>&2
            echo "Our override is still needed. Test passed."

            mkdir "$out"
          '';
      };
    };
    checkWhetherBroken // {
      example-usage = result;
      example-has-racket = hasBinary result "racket";
    };
}
