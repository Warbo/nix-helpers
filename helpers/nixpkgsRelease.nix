{ lib }:

with lib;
{
  def   = concatStrings (take 2 (splitString "." nixpkgsVersion));
  tests = {};
}
