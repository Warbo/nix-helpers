# Merge together a list of attrsets
{ lib }:

with lib;
fold (x: y: x // y) { }
