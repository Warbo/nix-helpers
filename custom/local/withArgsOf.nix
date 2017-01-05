{ lib, withArgs }:

with builtins;
#with lib;

# Return an eta-expanded wrapper around "g", which accepts the same named
# arguments as "f".
f: g:

with {
  fArgs = functionArgs f;
};
withArgs (filter (n: !fArgs."${n}") (attrNames fArgs)) g
