{ fetchFromGitHub, hasBinary, makeWrapper, racket, runCommand }:

rec {
  pkg = deps: runCommand "racket-with-deps"
    {
      inherit deps racket;
      buildInputs  = [ makeWrapper racket ];
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
      for PROG in "$racket"/bin/*
      do
        NAME=$(basename "$PROG")
        makeWrapper "$PROG" "$out/bin/$NAME" --set HOME "$out/etc"
      done
    '';

  tests =
    with {
      result = pkg [
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
    };
    [ result (hasBinary result "racket") ];
}
