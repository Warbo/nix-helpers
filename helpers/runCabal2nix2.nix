{ cabal2nix, cabal2nix2Cache, hackageDb, runCabal2nixGeneric }:

{
  def = runCabal2nixGeneric {
    inherit cabal2nix;
    cache     = cabal2nix2Cache;
    packageDb = hackageDb;
  };
  tests = {};
}
