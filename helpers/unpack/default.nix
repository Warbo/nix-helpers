# Extract a given tarball. If it's not a tarball, just copy.
{ unpack' }:

{
  def   = unpack' "unpack";
  tests = {};
}
