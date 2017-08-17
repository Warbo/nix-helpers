{}:

with builtins;
x: isFunction x || (isAttrs x && x ? __functor)
