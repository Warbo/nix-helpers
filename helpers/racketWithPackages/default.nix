{
  lib,
  makeWrapper,
  racket,
  runCommand,
}:

with {
  go =
    {
      racket,
      name ? "${racket.name}-with-deps",
    }:
    deps:
    runCommand name
      {
        inherit deps racket;
        buildInputs = [
          makeWrapper
          racket
        ];
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
};
lib.makeOverridable go { inherit racket; }
