{ cabal2nix, cabal2nixCache, haskellPackages, lib, pinnedCabal2nix ? cabal2nix,
  runCabal2nixGeneric, stableHackageDb, unpack' }:

rec {
  def = lib.makeOverridable runCabal2nixGeneric {
    cabal2nix = pinnedCabal2nix;
    cache     = cabal2nixCache;
    packageDb = stableHackageDb;
  };
  tests = {
    canGetHackage = def {
      name = "runCabal2nix-can-get-hackage";
      url  = "cabal://list-extras-0.4.1.4";
    };
    canGetDir = def {
      name = "runCabal2nix-can-get-dir";
      url  = unpack' "list-extras" haskellPackages.list-extras.src;
    };
  };
}
