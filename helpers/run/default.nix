{ bash, ghc, nixpkgs1609, python, runCommand, wrap }:

args: runCommand args.name {} (wrap (args // {
  name = "${args.name}-runner";
}))
