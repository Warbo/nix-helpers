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
  result = planPackages.callCabal2nix name src { };
};
result // {
  inherit cabalPlan hackageIndex;
  haskellPackages = planPackages;
}
