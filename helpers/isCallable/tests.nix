{ callPackage, isCallable, nothing }:

assert isCallable (callPackage ({ }: (x: abort "shouldn't force")) { });
nothing
