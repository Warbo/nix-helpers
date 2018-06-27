# Takes a directory path, returns any immediate children in that directory whose
# name matches '*.nix'. Result is an attrset where names are "basenames" with
# ".nix" suffix removed, e.g. "foo", and values are full paths with directory
# prefix and ".nix" suffix, e.g. "${dir}/foo.nix".
#
# Note that this is used to bootstrap nix-helpers, so it should work standalone.
{
  die ? import ./die.nix {},  # Provide fallback for bootstrapping
  lib
}:

with builtins;
with rec {
  content = dir: filter (lib.hasSuffix ".nix")
                        (attrNames (readDir dir));

  entry = dir: f: {
    name  = lib.removeSuffix ".nix" f;
    value = "${dir}/${f}";
  };

  go = dir: listToAttrs (map (entry dir) (content dir));

  testData = go ./.;

  thisFile = "${./.}/nixFilesIn.nix";
};
assert testData ? nixFilesIn || die {
  inherit testData;
  error = "Expected 'nixFilesIn' to appear in 'testData'";
};
assert testData.nixFilesIn == thisFile || die {
  inherit testData thisFile;
  error = "Expected 'testData.nixFilesIn' to match 'thisFile'";
};
assert dirOf testData.nixFilesIn == "${./.}" || die {
  inherit testData;
  thisDir = "${./.}";
  error   = "Expected 'testData.nixFilesIn' to be a file under 'thisDir'";
};
go
