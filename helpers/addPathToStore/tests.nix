{ addPathToStore, hello, writeScript }:

{
  self = addPathToStore ../addPathToStore/default.nix;
  dir = addPathToStore ./..;
  dirEntry = addPathToStore (./.. + "/addPathToStore/default.nix");
  dodgyName = addPathToStore (./.. + "/attrsToDirs'/default.nix");
  storePath = addPathToStore "${hello}";
  storeEntry = addPathToStore "${hello}/bin/hello";
  dodgyStore = addPathToStore "${./..}/attrsToDirs'/default.nix";
  notBuilt = with { f = writeScript "test-file" "1234"; };
    addPathToStore "${f}";
}
