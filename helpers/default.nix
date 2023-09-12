{ nixpkgs-lib, nixpkgs }:

with rec {
  inherit (builtins) attrNames getAttr;
  inherit (nixpkgs-lib) fold;

  callPackage = nixpkgs.newScope nix-helpers;

  # Bootstrap this function so we can use it to load all of our subdirs
  nixDirsIn = import ./nixDirsIn { };

  # Accumulate the results of 'addFile' for all files matching 'filename'
  allFiles = filename:
    with rec {
      # Import './name/filename' , appending the results to 'previous'
      addFile = name: previous:
        previous // {
          # Using 'callPackage' ensures derivations get appropriate 'override' attrs
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

  # Combine everything and tie the knot
  pinnedNixpkgs = import ./pinnedNixpkgs { inherit nixpkgs-lib; };

  nix-helpers = pinnedNixpkgs // defs // {
    inherit nix-helpers nixpkgs nixpkgs-lib;
    nix-helpers-tests = tests;
  };
};
nix-helpers
