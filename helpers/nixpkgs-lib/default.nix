# Standalone copy of Nixpkgs's "lib" attrset: smaller than depending on Nixpkgs!
{ nixpkgs-lib-rev ? "01fc4cd75e577ac00e7c50b7e5f16cd9b6d633e8"
, nixpkgs-lib-sha256 ?
  "sha256:10l1ndysycnfwfxrhchvvjdf1lwn7kj8f89cxwzvnf5m5grfdgm4"
, nixpkgs-lib-src ? fetchTarball {
  name = "nixpkgs-lib";
  url = "https://github.com/nix-community/nixpkgs.lib/archive/"
    + nixpkgs-lib-rev + ".tar.gz";
  sha256 = nixpkgs-lib-sha256;
} }:
import "${nixpkgs-lib-src}/lib"
