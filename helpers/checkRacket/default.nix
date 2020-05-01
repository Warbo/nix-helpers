# Checks for whether Racket is broken/unsupported on this arch/nixpkgs combo.
# We provide two important things:
#
#  - A boolean indicating whether (as we understand it) Racket is broken
#  - A test to check whether or not Racket is indeed broken or not
#
# Anyone making use of this boolean in their definition should also include the
# test in their suite, to see whether it's still accurate.
{ fail, nixpkgsRelease, path, runCommand, withNix }:

with builtins;
with {
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

  racket-override-not-needed = runCommand
    "racket-override-not-needed-for-nixpkgs${nixpkgsRelease}"
    (withNix { buildInputs = [ fail ]; })
    ''
      X=$(nix-instantiate -E '(import "${path}" {}).racket' 2>&1) ||
        fail "Couldn't instantiate Racket:\n$X\nSeems broken to me!"
      mkdir "$out"
    '';
};
rec {
  racketWorks = currentSystem != "i686-linux" ||
                compareVersions nixpkgsRelease "1703" == -1;

  checkWhetherBroken = if racketWorks
                          then { inherit racket-override-not-needed;   }
                          else { inherit racket-override-still-needed; };
}
