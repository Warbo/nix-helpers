# List Haskell package names whose test dependencies are cyclic. For example, a
# 'foo' library may depend on 'bar', and the test suite of 'bar' may depend on
# 'foo'. Naively this is cyclic, but if we put 'bar' in this list its tests
# suite will be skipped and the cycle will be broken.
{}:

{
  def   = [
    "binary"     # binary <-> Cabal
    "bytestring" # bytestring <-> test-framework
    "clock"      # clock <-> tasty
    "containers"
    "deepseq"    # deepseq <-> HUnit
    "pretty"     # QuickCheck -> template-haskell -> pretty -> QuickCheck
    "time"       # time <-> test-framework
  ];
  tests = {};
}
