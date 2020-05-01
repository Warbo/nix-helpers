{ lexCompare, lib }:

lib.sort (x: y: lexCompare x y == -1)
