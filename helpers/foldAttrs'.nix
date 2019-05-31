{ lib }:

with builtins;
with lib;
{
  def = f: z: attrs: fold (name: f name (getAttr name attrs))
                          z
                          (attrNames attrs);

  tests = {};
}
