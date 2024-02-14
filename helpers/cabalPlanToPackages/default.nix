{ haskell, haskellPackages, lib }:
with {
  inherit (builtins) filter listToAttrs map;
  oldHaskellPackages = haskellPackages;
};
{ cabalPlan, haskellPackages ? oldHaskellPackages }:
with rec {
  namesToVersions = map (pkg: {
    name = pkg.pkg-name;
    value = pkg.pkg-version;
  });

  chosenVersions = haskell.lib.packageSourceOverrides (listToAttrs
    (namesToVersions (filter (pkg: pkg.type != "pre-existing")
      (cabalPlan.install-plan or cabalPlan.json.install-plan))));

  fixes = self: super: {
    # TODO: Disable all tests, to prevent circular dependencies
    mkDerivation = lib.setFunctionArgs
      (args: super.mkDerivation (args // { doCheck = false; }))
      super.mkDerivation // {
        original = haskellPackages.mkDerivation;
      };

    # The splitmix package lists 'testu01' as a required "system dependency"
    testu01 = null;
  };
};
(haskellPackages.extend fixes).extend chosenVersions
