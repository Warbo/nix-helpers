{
  callPackage,
  isCallable,
  nothing,
}:

assert isCallable (callPackage (_: (x: abort "shouldn't force")) { });
nothing
