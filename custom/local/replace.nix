# Provide the 'replace' command from MariaDB, which is like sed without regexen.
# This command was removed in later versions of MariaDB.
{ boost159, darwin, mkBin, repo1609, self }:

with rec {
  mariadb = self.callPackage "${repo1609}/pkgs/servers/sql/mariadb" {
    # These overrides are copied from all-packages.nix in repo1609
    inherit (darwin) cctools;
    inherit (darwin.apple_sdk.frameworks) CoreServices;
    boost = boost159;
  };

  pkg = mkBin {
    name = "replace";
    file = "${mariadb.client.bin}/bin/replace";
  };
};
{
  inherit   pkg;
  tests = [ pkg ];
}
