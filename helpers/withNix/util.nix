{ lib }:

with builtins;
with lib;
{
  needWorkaround = compareVersions nixVersion "2" != -1;
}
