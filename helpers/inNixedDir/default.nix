{
  bash,
  mkBin,
  withNix,
}:

with builtins;
with {
  nixy = withNix { };
  file = ./inNixedDir.sh;
};
mkBin {
  inherit file;
  name = "inNixedDir";
  paths = nixy.buildInputs;
  vars = removeAttrs nixy [ "buildInputs" ];
}
// {
  file = "${file}";
}
