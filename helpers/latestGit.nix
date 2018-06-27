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
{ cacert, callPackage, die, fetchGitHashless, git, lib, nothing, repo1709,
  runCmd, sanitiseName, stdenv }:

with builtins;
with lib;
with rec {
  # We always use fetchgit from nixpkgs 17.09 since there was a change in 2016
  # which changed the hashes, and it's painful trying to handle both versions.
  fetchgit =
    with { pinned = path: callPackage "${repo1709}/${path}"; };
    pinned "pkgs/build-support/fetchgit" {
      stdenv = stdenv // (if stdenv.lib ? fetchers
                             then {}
                             else {
                               lib = stdenv.lib // {
                                 fetchers = pinned "lib/fetchers.nix" {};
                               };
                             });
    };

  # We need the url, but ref is optional (e.g. if we want a particular branch).
  # If nix-config is in stable mode 'stable' should have a 'rev' and a 'sha256'.
  # To force the latest version, even when we're supposed to be stable, the set
  # '{ unsafeSkip = true; }' can be used as the value of 'stable'. As its name
  # implies, this should be thought about carefully before using.
  go = { url, ref ? "HEAD", stable ? {}, ... }@args:
    with rec {
      gitArgs = removeAttrs args [ "ref" "stable" ];

      # In stable mode, we use the rev and sha256 hard-coded in 'stable'.
      stableRepo = fetchgit (gitArgs // { inherit (stable) rev sha256; });

      # In unstable mode, we look up the latest 'rev' dynamically
      unstableRepo = fetchGitHashless (gitArgs // { inherit rev; });

      # 'rev' can be given by the env vars 'REPO_REFS' or 'nix_git_rev_...'. If
      # not found in either, we run 'newRev' to query the URL for the latest
      # version.
      rev = if hasAttr url repoRefs
               then getAttr url repoRefs
                    else if keyRev == ""
                            then newRev
                            else keyRev;

      # The 'REPO_REFS' env var makes it easy to specify a bunch of revs at once
      repoRefStr = getEnv "REPO_REFS";
      repoRefs   = if repoRefStr == ""
                      then {}
                      else fromJSON repoRefStr;

      # The 'nix_git_rev_...' env vars make it easy to specify an individual rev
      key    = "${hashString "sha256" url}_${hashString "sha256" ref}";
      keyRev = getEnv "nix_git_rev_${key}";

      # Get commit ID for the given ref in the given repo. Takes a few seconds.
      newRev = import (runCmd "repo-${sanitiseName ref}-${sanitiseName url}"
        {
          inherit ref url;
          cacheBuster    = toString currentTime;
          GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
          buildInputs    = [ git ];
        }
        ''
          set -o pipefail
          # Commit ID is first awk 'field' in the first 'record'. Wrap in quotes.
          git ls-remote "$url" $ref | awk 'NR==1 {print "\""$1"\""}' > "$out"
        '');

      # If unsafeSkip is given, do what it says. If not, always get latest
      # (since that's what our name implies).
      getLatest = stable.unsafeSkip or true;

      error = msg: abort (toJSON { inherit msg url ref stable; });
    };
    assert getLatest || stable ? rev    || error "No stable rev";
    assert getLatest || stable ? sha256 || error "No stable sha256";
    if getLatest then unstableRepo else stableRepo;

  checks =
    with rec {
      url = "http://example.org";

      repos = {
        stable = go {
          inherit url;
          stable = { rev = "123"; sha256 = "abc"; unsafeSkip = false; };
        };

        unstable = go {
          inherit url;
          stable = { unsafeSkip = true; };
        };

        deep = go {
          inherit url;
          stable    = { rev = "123"; sha256 = "abc"; unsafeSkip = false; };
          deepClone = true;
        };
      };

      isDrv = name: isDerivation (getAttr name repos) || die {
        inherit name;
        error = "Test repo should give a derivation";
        type  = typeOf (getAttr name repos);
      };
    };
    all isDrv (attrNames repos);
};

{
  def   = go;
  tests = assert checks; nothing;
}
