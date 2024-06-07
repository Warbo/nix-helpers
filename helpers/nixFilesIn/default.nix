# Takes a directory path, returns any immediate children in that directory whose
# name matches '*.nix'. Result is an attrset where names are "basenames" with
# ".nix" suffix removed, e.g. "foo", and values are full paths with directory
# prefix and ".nix" suffix, e.g. "${dir}/foo.nix".
#
# Note that this is used to bootstrap nix-helpers, so it should work standalone.
{
  die ? import ../die { },
  suffixedFilesIn ? import ../suffixedFilesIn { },
}:

with builtins;
with rec {
  go = suffixedFilesIn ".nix";

  testData = go ./.;

  thisFile = ./default.nix;
};

assert
  testData ? default
  || die {
    inherit testData;
    error = "Expected 'default' to appear in 'testData'";
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
