# Augment the environment for a derivation by allowing Nix commands to be
# called inside the build process

{ nix }:

with builtins;
attrs: attrs // {
  buildInputs = (attrs.buildInputs or []) ++ [ nix ];
  NIX_PATH    = if getEnv "NIX_PATH" == ""
                   then "nixpkgs=${<nixpkgs>}"
                   else getEnv "NIX_PATH";
  NIX_REMOTE  = if getEnv "NIX_REMOTE" == ""
                   then "daemon"
                   else getEnv "NIX_REMOTE";
}
