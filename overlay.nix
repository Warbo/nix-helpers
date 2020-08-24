self: super:

with rec {
  inherit (builtins) abort attrNames getAttr;
  inherit (super.lib) fold;

  # Bootstrap this function so we can use it to load everything in helpers/
  nixFilesIn = (import ./helpers/nixFilesIn.nix { inherit (super) lib; }).def;

  # Map from name to path, e.g. { foo = ./helpers/foo.nix;, ... }
  nixFiles   = nixFilesIn ./helpers;

  # Import a nixFiles entry, given its name. Appends the results to 'previous'.
  mkPkg      = name: previous:
    with {
      # Like callPackage but gives access to 'super' for breaking loops
      these = self.newScope { inherit super; } (getAttr name nixFiles) {};
    };
    {
      defs  = previous.defs  // { "${name}" = these.def;   };
      tests = previous.tests // { "${name}" = these.tests; };
    };

  # Expose each attribute of pinnedNixpkgs separately too (repoX and nixpkgsX)
  nixpkgs = (import ./helpers/pinnedNixpkgs.nix {
    inherit (super) lib;
    die     = abort "Not used";
    nothing = abort "Not used";
  }).def;

  # Accumulate the contents of all helpers/ files
  inherit (fold mkPkg { defs = nixpkgs; tests = {}; } (attrNames nixFiles))
    defs tests;

  # Give nix-helpers a recursive reference to itself
  nix-helpers = defs // {
    inherit nix-helpers;
    nix-helpers-tests = tests;
  };
};
nix-helpers
