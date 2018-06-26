{ cabal-install, ghc, installHackage, runCommand }:

{ name, version ? "" }: runCommand "fetch-from-hackage"
  {
    arg         = name + (if version == "" then "" else "-${version}");
    buildInputs = [ cabal-install ghc installHackage ];
  }
  ''
    export HOME="$PWD/home"
    mkdir -p "$HOME"
    installHackage
    rm -f "$HOME/.cabal/packages/hackage.haskell.org/hackage-security-lock"

    mkdir got
    pushd got
      cabal get "$arg"
    popd
    mv got/* "$out"
  ''
