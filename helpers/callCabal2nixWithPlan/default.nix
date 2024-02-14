{ cabalPlan, cabalPlanToPackages, hackageIndex, haskellPackages }:
with {
  mkCabalPlan = cabalPlan;
  oldHackageIndex = hackageIndex;
  oldHaskellPackages = haskellPackages;
};
{ name, src, cabalFile ? "${src}/${name}.cabal", doBench ? false, doCheck ? true
, hackageIndex ? oldHackageIndex, haskellPackages ? oldHaskellPackages
, cabalPlan ?
  mkCabalPlan { inherit cabalFile doBench doCheck hackageIndex name; } }:
with rec {
  planPackages = cabalPlanToPackages { inherit cabalPlan haskellPackages; };
  result = planPackages.callCabal2nix name src
    # cabalPlanToPackages overrides mkDerivation to disable tests, to prevent
    # circular dependencies. The original mkDerivation function is kept in an
    # attribute: if it's present, use it (hence allowing this package's tests)
    (if planPackages.mkDerivation ? original then {
      mkDerivation = planPackages.mkDerivation.original;
    } else
      { });
};
result // {
  inherit cabalPlan hackageIndex;
  haskellPackages = planPackages;
}
