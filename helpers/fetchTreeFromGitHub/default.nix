# Like fetchFromGitHub but uses the given 'rev' as both the ID and outputHash.
# This only works when 'rev' is a Git tree, not a Git commit; to find the tree
# associated with a commit X, use 'git rev-parse X^{tree}'.
{
  gitTreeSingleton ? import ../gitTreeSingleton { },
}:
{
  owner,
  repo,
  tree,
}:
with {
  inherit (builtins)
    convertHash
    fetchurl
    hashFile
    path
    ;
  channelName = "${owner}-${repo}";
};
"${
  derivation {
    inherit channelName;
    name = "${owner}-${repo}-${tree}-unpacked";
    builder = "builtin:unpack-channel";
    system = "builtin";
    outputHashAlgo = "sha1";
    outputHashMode = "git";
    outputHash = convertHash {
      # The output of unpack-channel won't have tree as its SHA1 since it will
      # be wrapped in a directory (whose name matches channelName). However, we
      # can calculate the SHA1 of that wrapper, using tree and channelName!
      hash = hashFile "sha1" (gitTreeSingleton {
        name = channelName;
        sha1 = tree;
      });
      hashAlgo = "sha1";
      toHashFormat = "sri";
    };
    src = fetchurl {
      name = "${owner}-${repo}-${tree}.tar.gz";
      url = "https://github.com/${owner}/${repo}/archive/${tree}.tar.gz";
    };
  }
}/${channelName}"
