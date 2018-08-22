{ attrsToDirs', lib, repo1603, writeScript }:

rec {
  def = { name, repo }: attrsToDirs' name {
    "default.nix" = writeScript "${name}-default.nix" ''
      { overlays ? [], ... }@args:
        with { inherit (import "${repo}" {}) lib; };
        lib.fix (self: import "${repo}" (removeAttrs args [ "overlays" ] // {
                  config = (args.config or {}) // {
                    packageOverrides = super:
                      lib.foldl (old: f: old // f self super) {} overlays;
                    };
                  }))
    '';
  };

  tests = {
    self1603 =
      with rec {
        repo = def {
          name = "backport-overlays-1603-test";
          repo = repo1603;
        };

        got = import repo { overlays = [ (import ../overlay.nix) ]; };
      };
      assert got ? backportOverlays || die {
        error = ''
          Backporting nix-helpers overlay to nixpkgs 16.03 didn't produce a set
          containing backportOverlays.
        '';
      };
      got.dummyBuild "backport-overlays-nixpkgs1603";
  };
}
