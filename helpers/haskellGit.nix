# Takes the URL of a git repo containing a .cabal file (i.e. a Haskell project).
# Uses cabal2nix on the repo's HEAD.

with builtins;
{ nixFromCabal, withLatestGit }:
args@{ url, ref ? "HEAD", ... }:
  withLatestGit (args // {
    srcToPkg       = nixFromCabal;
    resultComposes = true;
  })
