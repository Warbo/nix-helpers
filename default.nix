# Returns nix-helpers from the latest entry in ./nixpkgs.nix
with rec {
  inherit (builtins) attrNames compareVersions getAttr;
  inherit (bootstrap) lib;
  inherit (lib) fold hasPrefix;
  inherit (import ./nixpkgs.nix {} { inherit lib; }) defs;

  # Some arbitrary nixpkgs repo, so we can use its 'lib'
  bootstrap = import (import ./nix/sources.nix).repo1909.outPath {
    config   = {};
    overlays = [];
  };

  # Find whichever repoXXXX entry has the newest version
  latest = fold (name: found: if found == null ||
                                 compareVersions name found == 1
                                 then name
                                 else found)
                null
                (attrNames defs);
};
(import (getAttr latest defs) {
  config   = {};
  overlays = [ (import ./overlay.nix) ];
}).nix-helpers
