{ newScope, nixFilesIn, suffixedFilesIn, ... }@args:
with rec {
  inherit (builtins) mapAttrs readFile;
  raw = mapAttrs (_: readFile) (suffixedFilesIn ".sh" ./hooks);
  nix = mapAttrs (_: f: newScope args f {}) (nixFilesIn ./hooks);
  combined = raw // nix;
};
combined // {
  defaults = builtins.attrValues {
    inherit (combined)
      haveGitIgnore
    ;
  };
}
