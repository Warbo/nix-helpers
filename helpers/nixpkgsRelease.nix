{ lib }:

with lib;
{
  def   = concatStrings (take 2 (splitString "." (lib.version or
                                                  lib.nixpkgsVersion)));
  tests = {};
}
