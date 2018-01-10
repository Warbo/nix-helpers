{ lib }:

with lib;
with rec {
  go = pred: l: if l == []
                   then []
                   else if pred (head l)
                           then go pred (tail l)
                           else l;
};
assert go (x: elem x [ 1 2 ]) [ 1 2 1 2 1 3 1 2 3 1 ] == [ 3 1 2 3 1 ];
assert go (abort "fail") [] == [];
go
