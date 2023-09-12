{ die, backportOverlays, repo1603 }:

{
  self1603 = with rec {
    repo = backportOverlays {
      name = "backport-overlays-1603-test";
      repo = repo1603;
    };

    got = import repo { overlays = [ (import ../../overlay.nix) ]; };
  };
    assert got ? backportOverlays || die {
      error = ''
        Backporting nix-helpers overlay to nixpkgs 16.03 didn't produce a set
        containing backportOverlays.
      '';
    };
    got.dummyBuild "backport-overlays-nixpkgs1603";
}
