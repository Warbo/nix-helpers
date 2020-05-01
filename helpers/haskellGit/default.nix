# Takes the URL of a git repo containing a .cabal file (i.e. a Haskell project).
# Uses cabal2nix on the repo's HEAD.
{ haskellSrc2nix, sanitiseName, withLatestGit }:
with builtins;
args@{ url, ref ? "HEAD", ... }:
  withLatestGit (args // {
    srcToPkg = src: haskellSrc2nix {
      inherit src;
      name = args.name or sanitiseName (baseNameOf url);
    };
  })
