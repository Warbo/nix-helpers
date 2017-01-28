{ cabal2nix, glibcLocales, hackageDb, nix, runCommand }:

with builtins;

{ url, args ? [] }:

runCommand "run-cabal2nix"
  {
    inherit url;
    inherit hackageDb;
    NIX_REMOTE  = "daemon";
    NIX_PATH    = builtins.getEnv "NIX_PATH";
    buildInputs = [ cabal2nix nix ];

    # Otherwise cabal2nix dies for accented characters
    LANG           = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";
  }
  ''
    export HOME="$PWD/home"
    cp -r "$hackageDb" ./home
    chmod 777 ./home

    cabal2nix ${concatStringsSep " " args} "$url" > "$out"
  ''
