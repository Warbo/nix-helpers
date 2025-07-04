{ lib }:
path:
with rec {
  inherit (builtins) baseNameOf length split toString;

  parts = split "\\." (baseNameOf (toString path));
};
if length parts > 1
then lib.last parts
else null
