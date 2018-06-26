# True if the list xs is a suffix of the list ys, or vice versa
{ lib, reverse }:

with builtins;
with lib;

xs: ys:
  with rec {
    lx     = length xs;
    ly     = length ys;
    minlen = if lx < ly then lx else ly;
  };
  take minlen (reverse xs) == take minlen (reverse ys)
