self: super:

with rec {
  inherit (builtins) attrNames getAttr;
  inherit (super.lib) fold;

  # Bootstrap this function so we can use it to load everything in helpers/
  nixFilesIn = (import ./helpers/nixFilesIn.nix { inherit (super) lib; }).def;

  # Map from name to path, e.g. { foo = ./helpers/foo.nix;, ... }
  nixFiles   = nixFilesIn ./helpers;

  # Import a nixFiles entry, given its name. Appends the results to 'previous'.
  mkPkg      = name: previous:
    with rec {
      # Like callPackage but also has access to nixpkgs, 'self' and 'super'
      these = self.newScope { inherit super; } (getAttr name nixFiles) {};
    };
    {
      defs  = previous.defs  // { "${name}" = these.def;   };
      tests = previous.tests // { "${name}" = these.tests; };
    };

  pinnedNixpkgs = import ./nixpkgs.nix self super;
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
