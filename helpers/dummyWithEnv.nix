{ runCmd }:

{
  def   = { name, value }: runCmd "${name}" { inherit value; } ''mkdir "$out"'';
  tests = {};
}
