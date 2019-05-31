{ lib, nixFilesIn }:
{
  def   = dir: lib.mapAttrs (_: import) (nixFilesIn dir);
  tests = {};
}
