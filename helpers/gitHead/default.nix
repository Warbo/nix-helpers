{ cacert, git, runCmd, sanitiseName }:

with builtins;
with rec {
  rev = { url, ref ? "HEAD", ... }:
    with rec {
      # The 'REPO_REFS' env var makes it easy to specify a bunch of revs at once
      repoRefStr = getEnv "REPO_REFS";
      repoRefs = if repoRefStr == "" then { } else fromJSON repoRefStr;

      # The 'nix_git_rev_...' env vars make it easy to specify an individual rev
      key = "${hashString "sha256" url}_${hashString "sha256" ref}";
      keyRev = getEnv "nix_git_rev_${key}";

      fetchRev = runCmd "repo-${sanitiseName ref}-${sanitiseName url}" {
        inherit ref url;
        __noChroot = true;
        cacheBuster = toString currentTime;
        GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        buildInputs = [ git ];
      } ''
        set -o pipefail
        # Commit ID is first awk 'field' in the first 'record'. Wrap in quotes.
        git ls-remote "$url" $ref | awk 'NR==1 {print "\""$1"\""}' > "$out"
      '';

      # Get commit ID for the given ref in the given repo. Takes a few seconds.
      newRev = import fetchRev;
    };
    # 'rev' can be given by the env vars 'REPO_REFS' or 'nix_git_rev_...'. If
    # not found in either, we run 'newRev' to query the URL for the latest
    # version.
    if hasAttr url repoRefs then
      getAttr url repoRefs
    else if keyRev == "" then
      newRev
    else
      keyRev;
};
rev
