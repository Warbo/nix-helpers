{ attrsToDirs, haskellPkgDepsSet, lib, writeScript }:

{ deps, extra-sources, hsPkgs, useOldZlib ? false }: haskellPkgDepsSet {
  inherit extra-sources hsPkgs useOldZlib;
  name = "dummy-for-deps";
  dir  = attrsToDirs {
    "dummy-for-deps.cabal" = writeScript "dummy-for-deps.cabal" ''
      name:                dummy-for-deps
      version:             1.0
      synopsis:            Dummy package
      homepage:            http://example.org
      license:             PublicDomain
      author:              Nobody
      maintainer:          nobody@example.org
      category:            Language
      build-type:          Simple
      cabal-version:       >= 1.10

      library
        build-depends:       ${lib.concatStringsSep "\n    , " deps}
        default-language:    Haskell2010
    '';
  };
}
