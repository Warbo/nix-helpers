{ lexCompare, lib }:
with lib;
{
  srt = sort (x: y: lexCompare x y == -1);
}
