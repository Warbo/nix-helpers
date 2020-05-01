{ lib }:

with lib;
concatStrings (take 2 (splitString "." (lib.version or
                                        lib.nixpkgsVersion)))
