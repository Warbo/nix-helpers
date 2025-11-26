{ fetchTreeFromGitHub, pkgs }:
with rec {
  inherit (builtins) head scopedImport;

  src = fetchTreeFromGitHub {
    owner = "cachix";
    repo = "git-hooks.nix";
    tree = "dc6f9fcfad80b7f4cfde53759452959a8853255d";
  };

  overlay =
    scopedImport
      {
        import = x: if x == null then ({ overlays, ... }: head overlays) else import x;
      }
      "${src}/nix"
      {
        nixpkgs = null;
        gitignore-nix-src = abort "gitignore-nix-src";
      };

  defs = overlay (pkgs // defs) pkgs;
};
{ defaultHooks = import ./defaultHooks.nix; } // defs
