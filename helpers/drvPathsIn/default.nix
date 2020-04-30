{ die, lib, pathsTo }:

with builtins;
with lib;
with {
  addPath = x: path: str:
    with {
      pre  = if str == null then "" else str + "\n";
      name = concatStringsSep "." path;
      drv  = attrByPath (path ++ [ "drvPath" ]) (die { inherit path; }) x;
    };
    pre + name + "	" + drv;
};
{
  def   = x: fold (addPath x) null (reverseList (pathsTo isDerivation x));
  tests = {};
}
