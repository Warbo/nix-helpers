{
  lib ? import ../nixpkgs-lib {},
  withArgs ? import ../withArgs { inherit lib; }
}:

# Return an eta-expanded wrapper around "g", which accepts the same named
# arguments as "f".
f: g:
with rec {
  inherit (builtins) attrNames filter functionArgs;
  fArgs = functionArgs f;
};
withArgs (filter (n: !fArgs."${n}") (attrNames fArgs)) g
