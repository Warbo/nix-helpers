{ mkStableHackageDb, nothing }:

with builtins;
rec {
  pkg   = (mkStableHackageDb {}).available;
  tests = [ (assert typeOf pkg == "list";
             nothing) ];
}
