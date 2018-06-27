{ lib }:

with lib;
concatStrings (take 2 (splitString "." nixpkgsVersion))
