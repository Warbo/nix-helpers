{
  nixpkgs-lib ? import ./nixpkgs-lib { },
  nixpkgs ? pinnedNixpkgs.nixpkgsLatest,
  pinnedNixpkgs ? import ./pinnedNixpkgs { inherit nixpkgs-lib; },
}:
with rec {
  inherit (builtins) attrNames getAttr isAttrs;
  inherit (nixpkgs-lib) fold mapAttrs;

  callPackage = nixpkgs.newScope nix-helpers;

  # Bootstrap this function so we can use it to load all of our subdirs
  nixDirsIn = import ./nixDirsIn { };

  # Accumulate the results of 'addFile' for all files matching 'filename'
  allFiles =
    filename:
    with rec {
      # Import './name/filename' , appending the results to 'previous'
      addFile =
        name: previous:
        previous
        // {
          # 'callPackage' ensures derivations get appropriate 'override' attrs
          "${name}" = callPackage (getAttr name found) { };
        };

      # Look for files with name 'filename' (e.g. "default.nix") in our
      # subdirectories. Returns a map from subdir name to path, e.g.
      # { foo = ./foo/default.nix;, ... }
      found = nixDirsIn {
        inherit filename;
        dir = ./.;
      };
    };
    fold addFile { } (attrNames found);

  # Load definitions from 'default.nix' and tests from 'tests.nix'.
  defs = allFiles "default.nix";
  tests = allFiles "tests.nix";

  # Takes its (lazy) values from defs.pinnedNixpkgs, but its (strict) keys from
  # pinnedNixpkgs; so it can be spliced into our result without looping.
  defPkgs = builtins.mapAttrs (n: _: defs.pinnedNixpkgs.${n}) pinnedNixpkgs;

  # Combine everything and tie the knot
  nix-helpers =
    defPkgs
    // defs
    // {
      inherit nix-helpers nixpkgs nixpkgs-lib;
      nix-helpers-tests = {
        recurseForDerivations = true;
      }
      // mapAttrs (
        _: x: if isAttrs x then { recurseForDerivations = true; } // x else x
      ) tests;
    };
};
nix-helpers
