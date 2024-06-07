{
  all-cabal-hashes,
  haskellPackages,
  lib,
  runCommand,
  writeScript,
}:

with {
  rev = lib.removePrefix "all-cabal-hashes-" all-cabal-hashes.name;

  mkHackageIndex = writeScript "mkHackageIndex" ''
    #!${
      haskellPackages.ghcWithPackages (pkgs: [
        pkgs.aeson
        pkgs.MissingH
        pkgs.tar
      ])
    }/bin/runhaskell
    ${builtins.readFile ./mkHackageIndex.hs}
  '';
};
runCommand "01-index-${rev}" { } ''
  < ${all-cabal-hashes} gunzip | ${mkHackageIndex} | gzip > "$out"
''
