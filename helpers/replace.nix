# Provide the 'replace' command from MariaDB, which is like sed without regexen.
# This command was removed in later versions of MariaDB.
{ boost159, callPackage, darwin, mkBin, repo1609 }:

with rec {
  mariadb = callPackage "${repo1609}/pkgs/servers/sql/mariadb" {
    # These overrides are copied from all-packages.nix in repo1609
    inherit (darwin) cctools;
    inherit (darwin.apple_sdk.frameworks) CoreServices;
    boost = boost159;
  };

  def = mkBin {
    name = "replace";
    file = "${mariadb.client.bin}/bin/replace";
  };
};
{
  inherit def;
  tests = def;
}
