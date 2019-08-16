{ checkRacket, lib, nixpkgs1609, racket }:

with builtins;
with lib;
with checkRacket;
with {
  # The racket argument can be overridden to break infinite loops, e.g. if we
  # want to replace 'racket' with 'checkedRacket' system-wide (in which case
  # 'then racket' will loop)
  go = { racket }: if racketWorks
                      then racket
                      else trace (concatStringsSep " " [
                                   "WARNING: Taking racket from nixpkgs 16.09,"
                                   "since newer versions are marked as broken on"
                                   "i686 nixpkgs."])
                                 nixpkgs1609.racket;
};
{
  def   = makeOverridable go { inherit racket; };
  tests = {};
}
