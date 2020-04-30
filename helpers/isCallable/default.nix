{ callPackage, nothing }:

with builtins;
rec {
  def   = x: isFunction x || (isAttrs x && x ? __functor);
  tests = assert def (callPackage ({}: (x: abort "shouldn't force")) {});
          nothing;
}
