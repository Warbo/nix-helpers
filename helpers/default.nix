{ callPackage, lib, pinnedNixpkgs }:

with builtins;
with lib;
with rec {
  # Bootstrap this function so we can use it to load all of our subdirs
  nixDirsIn = import ./nixDirsIn {};

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
  defs  = allFiles "default.nix";
  tests = allFiles "tests.nix";

  # Combine everything and tie the knot
  nix-helpers = defs // pinnedNixpkgs.defs // {
    inherit nix-helpers;
    nix-helpers-tests = tests // { pinnedNixpkgs = pinnedNixpkgs.tests; };
    pinnedNixpkgs     = pinnedNixpkgs.defs;
  };
};
nix-helpers // { inherit allFiles defs tests; nix-helpers-defs = defs; nix-helpers-tests = tests; }
