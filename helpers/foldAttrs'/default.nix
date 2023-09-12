{ lib }:

with builtins;
with lib;
f: z: attrs:
fold (name: f name (getAttr name attrs)) z (attrNames attrs)
