{ addPathsToStore, hello, writeScript }:

{
  self       = addPathsToStore ./addPathToStore.nix;
  dir        = addPathsToStore ./.;
  dirEntry   = addPathsToStore (./. + "/addPathToStore.nix");
  dodgyName  = addPathsToStore (./. + "/attrsToDirs'.nix");
  storePath  = addPathsToStore "${hello}";
  storeEntry = addPathsToStore "${hello}/bin/hello";
  dodgyStore = addPathsToStore "${./.}/attrsToDirs'.nix";
  notBuilt   =
    with {
      f = writeScript "test-file" "1234";
    };
    addPathsToStore "${f}";
}
