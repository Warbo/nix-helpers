{
  callPackage,
  composeWithArgs,
}:

callPackage (composeWithArgs (x: x) ({ hello }: hello)) { }
