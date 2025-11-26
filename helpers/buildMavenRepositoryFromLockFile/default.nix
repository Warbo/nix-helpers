# Required by ../mvn2nix/default.nix
with {
  withArgsOf = import ../withArgsOf { };
  func = import "${import ../mvn2nix/source.nix}/maven.nix";
};
withArgsOf func (args: (func args).buildMavenRepositoryFromLockFile)
