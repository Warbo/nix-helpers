{ callPackage, lib, pinnedNixpkgs }:

with builtins;
with lib;
with rec {
  # Bootstrap this function so we can use it to load everything in helpers/
  nixFilesIn = (import ./helpers/nixFilesIn.nix { inherit lib; }).def;

  # Map from name to path, e.g. { foo = ./helpers/foo.nix;, ... }
  nixFiles   = nixFilesIn ./helpers;

  # Import a nixFiles entry, given its name. Appends the results to 'previous'.
  mkPkg      = name: previous:
    with callPackage (getAttr name nixFiles) {};
    {
      defs  = previous.defs  // { "${name}" = def;   };
      tests = previous.tests // { "${name}" = tests; };
    };
};

# Accumulate the contents of all helpers/ files
with fold mkPkg { defs = {}; tests = {}; } (attrNames nixFiles);
with rec {
  nix-helpers = defs // pinnedNixpkgs.defs // {
    inherit nix-helpers;
    nix-helpers-tests = tests // { pinnedNixpkgs = pinnedNixpkgs.tests; };
    pinnedNixpkgs     = pinnedNixpkgs.defs;
  };
};
nix-helpers
