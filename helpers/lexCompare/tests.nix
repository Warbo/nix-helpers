{
  bash,
  dummyBuild,
  hello,
  lexCompare,
}:

assert -1 == lexCompare 1 2;
assert -1 == lexCompare "a" "b";
assert -1 == lexCompare [ 1 ] [ 2 ];
assert -1 == lexCompare { x = 1; } { x = 2; };
assert -1 == lexCompare { x = 1; } { y = 1; };
assert 0 == lexCompare (x: 1) (x: 2);
assert 0 == lexCompare null null;
assert 0 == lexCompare 1 1;
assert 0 == lexCompare "a" "a";
assert 0 == lexCompare [ 1 ] [ 1 ];
assert 0 == lexCompare { x = 1; } { x = 1; };
assert 1 == lexCompare 2 1;
assert 1 == lexCompare "b" "a";
assert 1 == lexCompare [ 2 ] [ 1 ];
assert 1 == lexCompare { x = 2; } { x = 1; };
assert 1 == lexCompare { y = 1; } { x = 1; };
assert 0 != lexCompare bash hello;
dummyBuild "lexCompare-checks"
