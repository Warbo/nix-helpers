# Allow git repos to be used without pre-determined revisions or hashes, in the
# same way we can use `src = ./.`.
#
# For example:
#
# let latestGit = import /path/to/latestGit.nix
#  in stdenv.mkDerivation {
#       name = "My Project";
#       src  = latestGit { url = "http://example.com/project.git"; };
#     }
#
# TODO: This duplicates some functionality of fetchgitrevision; wait for that
# API to settle down, then use it here.
{ callPackage, die, dummyBuild, fetchGitHashless, git, gitHead, lib, nothing,
  repo1709, stdenv }:

with builtins;
with lib;
with rec {
  # We always use fetchgit from nixpkgs 17.09 since there was a change in 2016
  # which changed the hashes, and it's painful trying to handle both versions.
  fetchgit =
    with { pinned = path: callPackage "${repo1709}/${path}"; };
    pinned "pkgs/build-support/fetchgit" {
      stdenv = stdenv // (if lib ? fetchers
                             then {}
                             else {
                               lib = lib // {
                                 fetchers = pinned "lib/fetchers.nix" {};
                               };
                             });
    };
};

# We need a url, but ref is optional (e.g. if we want a particular branch).
# If 'stable.unsafeSkip' (the name is legacy) is set to 'false' it forces a
# stable revision to be used (given by 'stable.rev' and 'stable.sha256').
{ url, ref ? "HEAD", stable ? {}, ... }@args:
  with rec {
    gitArgs = removeAttrs args [ "ref" "stable" ];

    # In stable mode, we use the rev and sha256 hard-coded in 'stable'.
    stableRepo = fetchgit (gitArgs // { inherit (stable) rev sha256; });

    # In unstable mode, we look up the latest 'rev' dynamically
    unstableRepo = fetchGitHashless (gitArgs // { rev = gitHead args; });

    # If unsafeSkip is given, do what it says. If not, always get latest
    # (since that's what our name implies).
    getLatest = stable.unsafeSkip or true;

    error = msg: abort (toJSON { inherit msg url ref stable; });
  };
  assert getLatest || stable ? rev    || error "No stable rev";
  assert getLatest || stable ? sha256 || error "No stable sha256";
  if getLatest then unstableRepo else stableRepo
