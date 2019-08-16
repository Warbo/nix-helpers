{ checkRacket, lib, nixpkgs1609, racket }:

with builtins;
with lib;
with checkRacket;
{
  def   = if racketWorks
             then racket
             else trace (concatStringsSep " " [
                          "WARNING: Taking racket from nixpkgs 16.09,"
                          "since newer versions are marked as broken on"
                          "i686 nixpkgs."])
                        nixpkgs1609.racket;
  tests = {};
}
