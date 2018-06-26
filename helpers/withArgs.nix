{ lib }:

with builtins;
with lib;

# Return an eta-expanded wrapper around "f", which accepts the named
# arguments "args".
# TODO: Hopefully Nix will get a feature to set a function's argument names
args: f:

with rec {

# Build a string "a,b,c" for the arguments "args"
arglist = concatStringsSep "," args;

# Strip any dependencies off our string, so it can be embedded
arglistF = unsafeDiscardStringContext arglist;

# Write an eta-expansion of "f", which accepts the arguments "args"
content = "f: args@{${arglistF}}: f args";

eta = import (toFile "withArgs.nix" content) f;

};

eta
