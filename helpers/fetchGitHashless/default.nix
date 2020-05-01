# Like fetchgit, but doesn't check against an expected hash. Useful if the
# commit ID is generated dynamically.
{ fetchgit, unfix }:

with builtins;
args: unfix (fetchgit (args // {
  # Use a dummy hash, to appease fetchgit's assertions
  sha256 = hashString "sha256" args.url;
}))
