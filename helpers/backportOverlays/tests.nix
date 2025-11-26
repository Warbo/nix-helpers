{
  die,
  dummyBuild,
  backportOverlays,
  repo1603,
}:

{
  self1603 =
    with rec {
      repo = backportOverlays {
        name = "backport-overlays-1603-test";
        repo = repo1603;
      };

      got = import repo { overlays = [ (_: _: { inherit dummyBuild; }) ]; };
    };
    assert
      got ? dummyBuild
      || die {
        error = ''
          Backporting overlays to nixpkgs 16.03 didn't produce a set containing
          dummyBuild.
        '';
      };
    got.dummyBuild "backport-overlays-nixpkgs1603";
}
