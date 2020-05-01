{ dummyWithEnv, setIn }:

with builtins;
dummyWithEnv {
  name  = "setIn-test";
  value = toJSON (setIn {
    path  = [ "x" ];
    value = 1;
    set   = {};
  });
}
