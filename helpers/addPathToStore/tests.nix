{ addPathToStore, hello, writeScript }:

{
  self       = addPathToStore ./addPathToStore.nix;
  dir        = addPathToStore ./.;
  dirEntry   = addPathToStore (./. + "/addPathToStore.nix");
  dodgyName  = addPathToStore (./. + "/attrsToDirs'.nix");
  storePath  = addPathToStore "${hello}";
  storeEntry = addPathToStore "${hello}/bin/hello";
  dodgyStore = addPathToStore "${./.}/attrsToDirs'.nix";
  notBuilt   =
    with {
      f = writeScript "test-file" "1234";
    };
    addPathToStore "${f}";
}
