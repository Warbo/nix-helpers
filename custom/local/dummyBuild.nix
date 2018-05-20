{ dummyWithEnv }:

rec {
  pkg   = name: dummyWithEnv { inherit name; value = ""; };
  tests = [ (pkg "dummyBuildTest") ];
}
