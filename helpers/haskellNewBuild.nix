{ cabal-install, cabalField, die, fail, ghc, hackageDb, hackageTimestamp,
  hasBinary, installHackage, replace, runCommand, withDeps }:

with builtins;
with rec {
  defaultGhc = ghc;

  pName = { name ? null, ... }@args:
    if name == null
       then cabalField { field = "name"; dir = src args; }
       else name;

  putHkg = { timestamp ? hackageTimestamp, ... }: installHackage.override {
    hackageDb = hackageDb.override {
      hackageTimestamp = timestamp;
    };
  };

  fetch = { package, ... }@args: runCommand "fetch-haskell-package"
    {
      inherit (args) package;
      buildInputs = [ cabal-install ghc (putHkg args) replace ];
    }
    ''
      # Put Hackage DB in ~/.cabal
      export HOME="$PWD/home"
      mkdir "$HOME"
      installHackage

      # Fetch source into a standalone directory
      mkdir get
      pushd get
        env 1>&2
        echo "Fetching '$package' using cabal get" 1>&2
        cabal get "$package"
        # Keep result
        shopt -s nullglob
        mv * "$out"
      popd
    '';

  src = { dir ? null, ... }@args: if dir == null
                                     then fetch args
                                     else dir;

  build = {
    dir          ? null,
    extra-inputs ? [],
    package      ? null,
    name         ? null,
    ghc          ? defaultGhc,
    timestamp    ? hackageTimestamp
  }@args:

    assert isInt timestamp || die {
      inherit timestamp;
      error = "timestamp must be int";
    };
    assert length (filter (x: x != null) [ dir package ]) == 1 || die {
      inherit dir package;
      error = "Need dir xor package";
    };
    runCommand "new-build-${pName args}"
      {
        src         = src args;
        buildInputs = [ cabal-install ghc (putHkg args) ] ++ extra-inputs;
        timestamp   = toString timestamp;
      }
      ''
        export HOME="$out/home"
        mkdir -p "$HOME"
        installHackage

        cp -r "$src" "$out/src"
        chmod -R +w "$out/src"
        pushd "$out/src"
          cabal new-build --index-state "@$timestamp"
        popd
      '';
};

rec {
  def = args: runCommand "new-built-${pName args}"
    { build = build args; }
    ''
      cat "$build/src"/*.cabal | grep -i '^ *executable' |
                                 sed -e 's/  */ /g'      |
                                 sed -e 's/^ *//g'       |
                                 cut -d ' ' -f2          |
                                 while read -r EXE
      do
        find "$build/src/dist-newstyle" -type f -name "$EXE" | while read -r F
        do
          mkdir -p "$out/bin"
          ln -s "$F" "$out/bin/$EXE"
        done
      done
    '';

  tests = {
    checkNoCache = runCommand "check-new-build-no-cache"
      {
        buildInputs = [ fail ];
        got         = build { package = "hpp"; };
      }
      ''
        find "$got" -type f -name '01-index.tar*' | while read -r F
        do
          fail "Cabal cache should be symlinked; found '$F'"
        done
        mkdir "$out"
      '';

    checkBin = hasBinary (def { package = "hpp"; }) "hpp";
  };
}
