{
  callPackage,
  isCallable,
  nothing,
}:

assert isCallable (callPackage (_: (_: abort "shouldn't force")) { });
nothing
