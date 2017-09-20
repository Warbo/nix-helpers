# Provide the 'replace' command from MySQL, which is like sed without regexen
{ libmysql, mkBin }:

mkBin {
  name = "replace";
  file = "${libmysql.bin}/bin/replace";
}
