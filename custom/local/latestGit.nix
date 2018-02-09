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
{ cacert, fetchGitHashless, git, lib, repo1709, runCmd, sanitiseName, self,
  stable, stdenv }:
with builtins // lib // { configIsStable = stable; };

# We need the url, but ref is optional (e.g. if we want a particular branch).
# If nix-config is in stable mode, 'stable' should have a 'rev' and a 'sha256'.
{ url, ref ? "HEAD", stable ? {} }@args:

with rec {
  # We always use fetchgit from nixpkgs 17.09 since there was a change in 2016
  # which changed the hashes, and it's painful trying to handle both versions.
  fetchgit = self.callPackage "${repo1709}/pkgs/build-support/fetchgit" {
    stdenv = if stdenv.lib ? fetchers
                then stdenv
                else stdenv // { lib = stdenv.lib // {
                  fetchers = self.callPackage "${repo1709}/lib/fetchers.nix" {};
                }; };
  };

  # In stable mode, we use the rev and sha256 hard-coded in 'stable'.
  stableRepo = fetchgit {
    inherit url;
    inherit (stable) rev sha256;
  };

  # In unstable mode, we look up the latest 'rev' dynamically
  unstableRepo = fetchGitHashless (removeAttrs (args // { inherit rev; })
                                               [ "ref" "stable" ]);

  # 'rev' can be given by the env vars 'REPO_REFS' or 'nix_git_rev_...'. If not
  # found in either, we run 'newRev' to query the URL for the latest version.
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


  # The 'nix_git_rev_...' env vars make it easy to specify one individual 'rev'
  key    = "${hashString "sha256" url}_${hashString "sha256" ref}";
  keyRev = getEnv "nix_git_rev_${key}";

  # Get the commit ID for the given ref in the given repo. Takes a few seconds.
  newRev = import (runCmd "repo-${sanitiseName ref}-${sanitiseName url}"
    {
      inherit ref url;
      cacheBuster    = toString currentTime;
      GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      buildInputs    = [ git ];
    }
    ''
      set -o pipefail
      # Commit ID is first (awk) 'field' in the first 'record'. Wrap in quotes.
      git ls-remote "$url" $ref | awk 'NR==1 {print "\""$1"\""}' > "$out"
    '');

  # Logic for choosing between stable and unstable
  useStable  = configIsStable && !unsafeSkip;
  unsafeSkip = stable.unsafeSkip or false;

  error = msg: abort (toJSON { inherit msg url ref stable; });
};

assert useStable -> stable ? rev    || error "No stable rev";
assert useStable -> stable ? sha256 || error "No stable sha256";
if useStable then stableRepo else unstableRepo
