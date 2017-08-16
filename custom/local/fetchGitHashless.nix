# Like fetchgit, but doesn't check against an expected hash. Useful if the
# commit ID is generated dynamically.
{ fetchgit, stdenv }:

with builtins;
args: stdenv.lib.overrideDerivation
        # Use a dummy hash, to appease fetchgit's assertions
        (fetchgit (args // { sha256 = hashString "sha256" args.url; }))

        # Remove the hash-checking
        (old: {
          outputHash     = null;
          outputHashAlgo = null;
          outputHashMode = null;
          sha256         = null;
        })
