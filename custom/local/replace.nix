# Provide the 'replace' command from MySQL, which is like sed without regexen
{ nixpkgs1609, mkBin }:

# libmysql doesn't have a bin attribute in nixpkgs 16.03

mkBin {
  name = "replace";
  file = "${nixpkgs1609.libmysql.bin}/bin/replace";
}
