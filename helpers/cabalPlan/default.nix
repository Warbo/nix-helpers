{
  cabal-install,
  callPackage,
  ghc,
  hackageIndex,
  lib,
  runCommand,
}:
with { oldHackageIndex = hackageIndex; };
{
  name,
  cabalFile,
  doCheck ? true,
  doBench ? false,
  hackageIndex ? oldHackageIndex,
}:
with {
  plan =
    runCommand "${name}-plan.json"
      {
        buildInputs = [
          cabal-install
          ghc
          (callPackage ./fakeCurl.nix { inherit hackageIndex; })
        ];
        CABAL_CONFIG = builtins.toFile "dummy-cabal.config" ''
          repository repo
            url: http://example.org/
            secure: True
            root-keys: []
            key-threshold: 0
        '';
      }
      ''
        export HOME="$PWD"
        mkdir -p "$HOME/.cache/cabal"
        cabal update
        cp ${lib.escapeShellArg "${cabalFile}"} ./${lib.escapeShellArg "${name}.cabal"}
        cabal build --dry-run ${if doCheck then "--enable-tests" else ""} ${
          if doBench then "--enable-benchmarks" else ""
        }
        mv dist-newstyle/cache/plan.json "$out"
      '';
};
plan // { json = lib.importJSON plan; }
