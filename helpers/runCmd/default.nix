# Avoid passAsFile since 'unstable.runCommand' suffers an issue similar to
# https://github.com/NixOS/nixpkgs/issues/16742
{ runCommand }:

name: env:
runCommand name ({ passAsFile = [ ]; } // env)
