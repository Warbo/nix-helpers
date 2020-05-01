# Merge together a list of attrsets
{ die, lib }:

with lib;
fold (x: y: x // y) {}
