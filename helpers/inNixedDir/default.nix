{ mkBin, nix }:

with rec {
  file = ./inNixedDir.sh;
  got = builtins.getEnv "NIX_PATH";
};
mkBin {
  inherit file;
  name = "inNixedDir";
  paths = [ nix.out ];
  vars.NIX_PATH = if got == "" then "nixpkgs=${<nixpkgs>}" else got;
}
// {
  file = "${file}";
}
