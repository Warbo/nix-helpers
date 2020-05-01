{ callPackage, getType, hello }:

assert getType                       hello == "derivation";
assert getType                          {} == "set";
assert getType                      (x: x) == "callable";
assert getType (callPackage ({}: x: x) {}) == "callable";
assert getType                          [] == "list";
{}
