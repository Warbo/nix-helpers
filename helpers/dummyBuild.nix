{ dummyWithEnv }:

rec {
  def   = name: dummyWithEnv { inherit name; value = ""; };
  tests = def "dummyBuildTest";
}
