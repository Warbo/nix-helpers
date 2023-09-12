{ callPackage, lib, pinnedNixpkgs }:

with rec {
  inherit (builtins) attrNames getAttr;
  inherit (lib) fold;

  # Bootstrap this function so we can use it to load all of our subdirs
  nixDirsIn = import ./nixDirsIn { };

  # Look for files with name 'filename' (e.g. "default.nix") in our
  # subdirectories. Returns a map from subdir name to path, e.g.
  # { foo = ./foo/default.nix;, ... }
  nixFiles = filename: nixDirsIn { inherit filename; dir = ./.; };

  # Import './name/filename' , appending the results to 'previous'
  addFile = filename: name: previous: previous // {
    # Using 'callPackage' ensures derivations get appropriate 'override' attrs
    "${name}" = callPackage (getAttr name (nixFiles filename)) {};
  };

  # Accumulate the results of 'addFile' for all files matching 'filename'
  allFiles = filename: fold (addFile filename)
                            {}
                            (attrNames (nixFiles filename));

  # Load definitions from 'default.nix' and tests from 'tests.nix'.
  defs = allFiles "default.nix";
  tests = allFiles "tests.nix";

  # Combine everything and tie the knot
  nix-helpers = defs // pinnedNixpkgs // {
    inherit nix-helpers;
    nix-helpers-tests = tests;
  };
};
nix-helpers
