{ mkStableHackageDb }:

rec {
  pkg = (mkStableHackageDb {}).installed;
  tests = [ pkg ];
}
