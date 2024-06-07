{
  die ? import ../die { },
  nixpkgs-lib ? import ../nixpkgs-lib { },
}:

with rec {
  inherit (builtins)
    attrNames
    filter
    listToAttrs
    map
    readDir
    ;

  inherit (nixpkgs-lib) hasSuffix removeSuffix;

  go =
    suffix: dir:
    with {
      content = filter (hasSuffix suffix) (attrNames (readDir dir));

      entry = f: {
        name = removeSuffix suffix f;
        value = dir + "/${f}";
      };
    };
    listToAttrs (map entry content);

  testData = go ".nix" ./.;
  thisFile = ./default.nix;
};
assert
  testData ? default
  || die {
    inherit testData;
    error = "Expected default to appear in testData";
  };
assert
  testData.default == thisFile
  || die {
    inherit testData thisFile;
    error = "Expected 'testData.default' to match 'thisFile'";
  };
assert
  dirOf testData.default == ./.
  || die {
    inherit testData;
    thisDir = ./.;
    error = "Expected 'testData.default' to be a file under 'thisDir'";
  };
go
