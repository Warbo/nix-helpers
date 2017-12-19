{ cabal2nix, glibcLocales, latestGit, lib, runCommand, stable, stableHackageDb,
  withNix }:

with builtins;
with lib;

{
  name ? "",

  # Package location, containing a .cabal file, e.g. path, git repo, "cabal://"
  url,

  # Extra arguments for cabal2nix command. NOTE: you must quote things yourself,
  # if needed. Also, the available options may vary between cabal2nix versions.
  args ? [],

  # Hackage repo contents to use. Get the latest content (via 'cabal update') by
  # using hackageDb, but this doesn't cache well. Defaults to stableHackageDb,
  # which is built from a fixed git revision and hence caches well.
  packageDb ? stableHackageDb
}:

runCommand "run-cabal2nix${if name == "" then "" else "-${name}"}"
  (withNix {
    inherit packageDb;
    buildInputs = [ cabal2nix ];

    # Otherwise cabal2nix dies for accented characters
    LANG           = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

    # cabal2nix version 20160308 breaks for git repos by trying to import
    # nixexprs as JSON; we work around this by fetching separately.
    url = if hasPrefix "http" url && hasSuffix ".git" url
             then (if stable then trace "Warning: latestGit '${url}'" else id)
                  latestGit { inherit url; stable = { unsafeSkip = true; }; }
             else url;
  })
  ''
    set -e
    export HOME="$PWD/home"
    cp -r "$packageDb" ./home
    chmod 777 ./home

    cabal2nix ${concatStringsSep " " args} "$url" > "$out"
  ''
