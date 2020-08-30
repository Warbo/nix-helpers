# Evaluate and/or build all derivations in a release.nix file
{ attrsToDirs', bash, fail, lib, repoLatest, withNix, wrap }:

with rec {
  inherit (lib) cleanSource;

  nix_release_eval = wrap {
    name  = "nix_release_eval";
    paths = (withNix {}).buildInputs ++ [ bash fail ];
    vars  = withNix {
      attrs = ''
        (import "${cleanSource ../..}").drvPathsIn (import ./release.nix)
      '';
    };
    script = ''
      #!${bash}/bin/bash
      set -e

      [[ -e release.nix ]] || fail "No release.nix found, aborting"

      echo "Finding derivations" 1>&2
      nix eval --show-trace --raw "$attrs"
    '';
  };

  nix_release = wrap {
    name  = "nix_release";
    file  = ./nix_release.sh;
    paths = [ bash fail ];
    vars  = { inherit nix_release_eval; };
  };
};
attrsToDirs' "nix_release" {
  bin = { inherit nix_release nix_release_eval; };
}
