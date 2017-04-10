{ cabal2nix, glibcLocales, hackageDb, latestGit, lib, nix, runCommand }:

with builtins;
with lib;

{ url, args ? [] }:

runCommand "run-cabal2nix"
  {
    inherit hackageDb;
    NIX_REMOTE  = "daemon";
    NIX_PATH    = builtins.getEnv "NIX_PATH";
    buildInputs = [ cabal2nix nix ];

    # Otherwise cabal2nix dies for accented characters
    LANG           = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

    # cabal2nix version 20160308 breaks for git repos by trying to import
    # nixexprs as JSON; we work around this by fetching separately.
    url = if hasPrefix "http" url && hasSuffix ".git" url
             then latestGit { inherit url; }
             else url;
  }
  ''
    set -e
    export HOME="$PWD/home"
    cp -r "$hackageDb" ./home
    chmod 777 ./home

    cabal2nix ${concatStringsSep " " args} "$url" > "$out"
  ''
