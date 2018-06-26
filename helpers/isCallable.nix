{ callPackage, nothing }:

with builtins;
rec {
  pkg   = x: isFunction x || (isAttrs x && x ? __functor);
  tests = assert pkg (callPackage ({}: (x: abort "shouldn't force")) {});
          nothing;
}
