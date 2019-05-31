# Remove disallowed characters from a string, for use as a name
{ lib }:

with builtins;
with lib;
{
  def = stringAsChars (c: if elem c (lowerChars ++ upperChars)
                             then c
                             else "");

  tests = {};
}
