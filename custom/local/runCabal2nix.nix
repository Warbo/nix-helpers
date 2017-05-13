{ cabal2nix, glibcLocales, hackageDb, latestGit, lib, runCommand, withNix }:

with builtins;
with lib;

{ url, args ? [] }:

trace "FIXME: Can we use callCabal2nix yet?" runCommand "run-cabal2nix"
  (withNix {
    inherit hackageDb;
    buildInputs = [ cabal2nix ];

    # Otherwise cabal2nix dies for accented characters
    LANG           = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

    # cabal2nix version 20160308 breaks for git repos by trying to import
    # nixexprs as JSON; we work around this by fetching separately.
    url = if hasPrefix "http" url && hasSuffix ".git" url
             then latestGit { inherit url; }
             else url;
  })
  ''
    set -e
    export HOME="$PWD/home"
    cp -r "$hackageDb" ./home
    chmod 777 ./home

    cabal2nix ${concatStringsSep " " args} "$url" > "$out"
  ''
