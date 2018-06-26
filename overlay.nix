self: super:

with builtins;
with super.lib;
with rec {
  # Various pinned nixpkgs versions
  pinned     = import ./nixpkgs.nix { inherit (super) fetchFromGitHub lib; };
  nixpkgs    = pinned // { pinnedNixpkgs = pinned; };

  # Bootstrap this function so we can use it to load everything in helpers/
  nixFilesIn = import ./helpers/nixFilesIn.nix { inherit (super) lib; };

  # Map from name to path, e.g. { foo = ./helpers/foo.nix;, ... }
  nixFiles   = nixFilesIn ./helpers;

  # Import a nixFiles entry, given its name. Appends the results to 'previous'.
  mkPkg      = name: previous:
    with rec {
      # Like callPackage but also has access to nixpkgs, 'self' and 'super'
      these  = self.newScope (nixpkgs // { inherit self super; })
                             (getAttr name nixFiles)
                             {};
      tests  = these.tests or {};
    };
    {
      defs  = previous.defs  // { "${name}" = these.def or these; };
      tests = previous.tests // (if tests == {}
                                    then {}
                                    else { "${name}" = tests; });
    };

  # Accumulate the contents of all helpers/ files
  results = fold mkPkg { defs = {}; tests = {}; } (builtins.attrNames nixFiles);
};
nixpkgs // results.defs // { nix-helpers-tests = results.tests; }
