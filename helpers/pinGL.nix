{ attrsToDirs', backportOverlays, die, fetchFromGitHub, hasBinary, lib,
  nixpkgs1609, repo1609, wrap }:

#with builtins;
with rec {
  nixGL = fetchFromGitHub {
    owner  = "guibou";
    repo   = "nixGL";
    rev    = "a02970d";
    sha256 = "1a5cd1zbrd3gnb86iyfy5p9x46gdg463w37hhpa1nfp42lc8zcg2";
  };

  go = {
    # The nixpkgs repo we should take the GL driver from
    nixpkgsRepo,

    # The package whose binaries we'll wrap
    pkg,

    # The names of the binaries to wrap
    binaries,

    # The GL driver to wrap with (Intel means any built-in Mesa driver)
    gl ? "Intel"
  }:
  assert with builtins; isList binaries && binaries != [] || die {
    error  = "'binaries' should be a non-empty list of program names";
    type   = typeOf binaries;
    length = if isList binaries then length binaries else "N/A";
  };
  with {
    wrappers    = import nixGL { pkgs = import nixpkgsRepo; };
    wrapperName = "nixGL" + (if gl == "Mesa" then "Intel" else gl);
  };
  assert builtins.hasAttr wrapperName wrappers || die {
    inherit gl wrapperName;
    error    = "GL wrapper not found (note that Intel == Mesa)";
    wrappers = attrNames wrappers;
    given    = wrapperName;
  };
  attrsToDirs' "gl-wrapped-${pkg.name}" {
    bin = lib.genAttrs binaries (name: wrap {
      inherit name;
      paths  = [ (builtins.getAttr wrapperName wrappers) ];
      script = ''
        #!/usr/bin/env bash
        exec "${wrapperName}" "${pkg}/bin/${name}" "$@"
      '';
    });
  };
};
{
  def   = go;
  tests = {
    intelFirefox1609 = hasBinary (go {
      nixpkgsRepo = backportOverlays {
                      name = "nixpkgs1609-for-firefox";
                      repo = repo1609;
                    };
      pkg         = nixpkgs1609.firefox;
      binaries    = [ "firefox" ];
      gl          = "Intel";
    }) "firefox";
  };
}
