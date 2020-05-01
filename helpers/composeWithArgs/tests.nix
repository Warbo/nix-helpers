{ callPackage, composeWithArgs, hello }:

callPackage (composeWithArgs (x: x) ({ hello }: hello)) {}
