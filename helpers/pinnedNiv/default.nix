{ nix-helpers-sources }:

{
  def   = (import nix-helpers-sources.niv.outPath {}).niv;
  tests = {};
}
