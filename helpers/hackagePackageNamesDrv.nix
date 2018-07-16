{ mkStableHackageDb }:

{
  def   = (mkStableHackageDb {}).availableDrv;

  tests = {};
}
