{ cabalField, die, haskellPkgDepsSet, runCommand, withDeps }:

args:
  with builtins;
  with rec {
    inherit (haskellPkgDepsSet args) gcRoots hsPkgs;

    name = cabalField {
      inherit (args) dir;
      field = "name";
    };

    pkg = runCommand "just-binaries-of-${unsafeDiscardStringContext name}"
      { src = getAttr name hsPkgs; }
      ''
        mkdir "$out"
        [[ -e "$src/bin" ]] && ln -s "$src/bin"
      '';
  };
  assert isList gcRoots || die {
    inherit gcRoots;
    error = "gcRoots must be list";
  };
  assert isString name || die {
    inherit name;
    error = "name must be string";
  };
  withDeps gcRoots pkg
