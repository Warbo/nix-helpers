{ dummyBuild }:
rec {
  pkg   = dummyBuild "nothing";
  tests = pkg;
}
