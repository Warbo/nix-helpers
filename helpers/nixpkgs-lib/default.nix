# Standalone copy of Nixpkgs's "lib" attrset: smaller than depending on Nixpkgs!
{ rev ? "c30b6a84c0b84ec7aecbe74466033facc9ed103f"
, sha256 ? "sha256:194p8gfn5pvwq1naz47z6z7ncpr4bkxicjik756sw8sfw96f99yv", src ?
  fetchTarball {
    inherit sha256;
    name = "nixpkgs-lib";
    url = "https://github.com/nix-community/nixpkgs.lib/archive/${rev}.tar.gz";
  } }:
import "${src}/lib"
