# The racket argument can be overridden to break infinite loops, e.g. if we
# want to replace 'racket' with 'checkedRacket' system-wide (in which case
# 'then racket' will loop)

{
  checkRacket,
  lib,
  nixpkgs1609,
  racket,
  repo1609,
  stdenv,
}:

with builtins;
with lib;
with rec {
  linuxFallback = trace (concatStringsSep " " [
    "WARNING: Taking racket from nixpkgs 16.09,"
    "since newer versions are marked as broken on"
    "i686 nixpkgs."
  ]) nixpkgs1609.racket;

  macPkgs = import "${repo1609}" {
    config = {
      packageOverrides = super: {
        dejavu_fonts = {
          minimal = "";
        }; # Don't work on macOS
      };
    };
  };

  macFallback = trace (concatStringsSep " " [
    "WARNING: Taking racket from nixpkgs 16.09,"
    "since newer versions don't support macOS."
  ]) macPkgs.racket;
};
with checkRacket;
if racketWorks then
  racket
else if stdenv.isDarwin then
  macFallback
else
  linuxFallback
