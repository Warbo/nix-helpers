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

{ cacert, fetchGitHashless, git, gnused, runCommand, sanitiseName }:

with builtins;

# We need the url, but ref is optional (e.g. if we want a particular branch)
{ url, ref ? "HEAD" }@args:
  with rec {
    # We allow refs to be given in two ways: as a standalone env var...
    key    = "${hashString "sha256" url}_${hashString "sha256" ref}";
    keyRev = getEnv "nix_git_rev_${key}";

    # Or as an entry in a JSON table
    repoRefStr = getEnv "REPO_REFS";
    repoRefs   = if repoRefStr == ""
                    then {}
                    else fromJSON repoRefStr;

    # Get the commit ID for the given ref in the given repo.
    newRev = import (runCommand
      "repo-${sanitiseName ref}-${sanitiseName url}"
      {
        inherit ref url;

        # Avoids caching. This is a cheap operation and needs to be up-to-date
        version = toString currentTime;

        # Required for SSL
        GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";

        buildInputs = [ git gnused ];
      }
      ''
        REV=$(git ls-remote "$url" "$ref") || exit 1

        printf '"%s"' $(echo "$REV"        |
                        head -n1           |
                        sed -e 's/\s.*//g' ) > "$out"
      '');

    rev = repoRefs.url or (if keyRev == ""
                              then newRev
                              else keyRev);
};
fetchGitHashless (removeAttrs (args // { inherit rev; }) [ "ref" ])
