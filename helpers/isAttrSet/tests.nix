{ callPackage, hello, isAttrSet }:

assert   isAttrSet {};
assert   isAttrSet { x = "y"; };
assert !(isAttrSet hello);
assert !(isAttrSet (callPackage ({}: x: x) {}));
assert !(isAttrSet []);
assert !(isAttrSet null);
{}
