{ buildEnv, cabal-install, fetchFromGitHub, ghc, makeWrapper, runCommand,
  stdenv, writeScript }:

with rec{
  all-cabal-files = fetchFromGitHub {
    owner  = "commercialhaskell";
    repo   = "all-cabal-files";
    rev    = "c008e28";
    sha256 = "0kfcc7dw6sahgkv130r144pfjsxwzq8h479fw866nf875frvpblz";
  };

  # 00-index.tar, used by Cabal to check versions, dependencies, etc. This takes
  # a while to build, so we keep it in a standalone derivation to reduce the
  # chance that it'll need to be rebuilt (e.g. due to a dodgy test)
  repoCache = stdenv.mkDerivation {
    name = "hackage-00-index.tar";
    src  = all-cabal-files;

    unpackPhase = "true";  # Without this, src will be copied, which takes ages
    buildPhase  = ''
      BASE="$PWD"

      tar cf 00-index.tar -T /dev/null

      echo "Adding package dirs to 00-index.tar" 1>&2
      pushd "$src"
        for F in *
        do
          echo "Adding $F" 1>&2
          tar rf "$BASE/00-index.tar" "$F"
        done
      popd
    '';

    installPhase = ''
      cp -r 00-index.tar "$out"
    '';
  };

  # Command to install repo cache into ~/.cabal
  makeCabalConfigCmd = writeScript "makeCabalConfig" ''
    #!/usr/bin/env bash
    [[ -e "$HOME" ]] || {
      echo "makeCabalConfig requires HOME to put config into" 1>&2
      exit 1
    }
    DIR="$HOME/.cabal/packages/hackage.haskell.org"
    mkdir -p "$DIR"
    TARGET=$(readlink -f "$REPOCACHE")
    cp "$TARGET" "$DIR/00-index.tar"
  '';
};

stdenv.mkDerivation {
  name        = "stable-cabal-config";
  src         = makeCabalConfigCmd;
  buildInputs = [ cabal-install ghc makeWrapper ];
  REPOCACHE   = repoCache;
  unpackPhase = "true";

  doCheck     = true;
  checkPhase  = ''
    echo "Making config" 1>&2
    export HOME="$PWD"
    "$src"

    echo "Testing non-sandboxed install" 1>&2
    cabal install list-extras

    echo "Testing install into a sandbox" 1>&2
    cabal sandbox init
    cabal install list-extras
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    ln -s "$REPOCACHE" "$out/00-index.tar"
    makeWrapper "$src" "$out/bin/makeCabalConfig" \
      --set REPOCACHE "$out/00-index.tar"
  '';
}
