# Like fetchFromGitHub but uses the given 'rev' as both the ID and outputHash.
# This only works when 'rev' is a Git tree, not a Git commit; to find the tree
# associated with a commit X, use 'git rev-parse X^{tree}'.
{ nixpkgs }:
{ owner, repo, tree }: (nixpkgs.fetchFromGitHub {
  inherit owner repo;
  rev = tree;
  hash = builtins.convertHash {
    hash = tree;
    hashAlgo = "sha1";
    toHashFormat = "sri";
  };
}).overrideAttrs (_: { outputHashMode = "git"; })
