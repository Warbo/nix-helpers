{ asPath, glibcLocales, haskellPackages, haskellTestCycles, latestGit, lib,
  nothing, runCmd, unpack, withArgsOf, withNix }:

with builtins;
with lib;
with rec {
  warn = url: trace (toJSON {
    inherit url;
    warning  = "deprecated";
    function = "runCabal2nix";
    message  = ''
      runCabal2nix is deprecated, since nixpkgs 18.03 includes equivalent
      functionality such as callHackage, hackage2nix and haskellSrc2nix.
    '';
  });

  # Sets up the environment for running cabal2nix (lots of pettiness)
  env = { cabal2nix, cache, packageDb, url, ... }: warn url withNix {
    inherit packageDb;
    buildInputs = [ cabal2nix ];

    # Otherwise cabal2nix dies for accented characters
    LANG           = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

    cacheDir = if hasPrefix "cabal://" url
                  then cache
                  else "/no-cabal2nix-cache";

    # cabal2nix version 20160308 breaks for git repos by trying to import
    # nixexprs as JSON; we work around this by fetching separately.
    url = if hasPrefix "http" url && hasSuffix ".git" url
             then trace "Warning: latestGit '${url}'" latestGit {
                    inherit url;
                    stable = { unsafeSkip = true; };
                  }
             else url;
  };

  # This is the actual implementation which runs cabal2nix and (possibly) caches
  go =
    {
      name ? "unknown",

      # Where results should be cached to
      cache,

      # Package containing a .cabal file, e.g. path, git repo, "cabal://"
      url,

      # Extra arguments for cabal2nix command. NOTE: Quote things yourself if
      # needed. Also, the available options may vary between cabal2nix versions.
      args ? null,

      # Hackage contents to use. Get the latest content (via 'cabal update') by
      # using hackageDb, but that doesn't cache well. Defaults to
      # stableHackageDb, which does since it's built from a fixed git rev.
      packageDb,
      ...
    }@given: runCmd "run-cabal2nix-${name}" (env given) ''
         set -e
         export HOME="$PWD/home"
         cp -r "$packageDb" ./home
         chmod 777 ./home

         cabal2nix ${if args == null
                        # Force some things by default; this can be disabled by
                        # passing in '[]' for 'args'. Always avoid slow haddock.
                        then "--no-haddock"
                        else concatStringsSep " " args} "$url" > "$out"

         ${if args == null
              then ''
                # Check to see if this package should have its tests disabled
                N=$(grep 'pname' < "$out" | grep -o '"[^"]*"' | tr -d '"')
                for M in ${concatStringsSep " " haskellTestCycles}
                do
                  if [[ "x$N" = "x$M" ]]
                  then
                    echo "Disabling tests for '$N' to avoid cycles" 1>&2
                    cabal2nix --no-haddock --no-check "$url" > "$out"
                    break
                  fi
                done
              ''
              else ""}

         if [[ -e "$cacheDir" ]]
         then
           NAMEVER=$(echo "$url" | cut -d '/' -f 3-)
           DEST="$cacheDir/exprs/$NAMEVER.nix"
           [[ -e "$DEST" ]] || {
             echo "Caching result to '$DEST'" 1>&2
             cp "$out" "$DEST" || echo "Failed to cache, oh well" 1>&2
             chmod 777 "$DEST" || echo "Failed to cache, oh well" 1>&2
           }
         fi
       '';

  # Looks up from the cache if available, otherwise builds (and caches)
  cached = { url, cache, ... }@args:
    with { c = cache + "/exprs/${removePrefix "cabal://" url}.nix"; };
    if hasPrefix "cabal://" url && pathExists c
       then trace "Using cache: ${c}" (asPath c)
       else go args;
};
{
  def   = { cabal2nix, cache, packageDb }@args1:
            withArgsOf go (args2: cached (args1 // args2));
  tests = {};
}
