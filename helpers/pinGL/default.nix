# Wraps programs using 'nixGL', which lets us use different OpenGL libraries on
# the same system. NixOS struggles to maintain purity when it comes to OpenGL
# drivers: we can build any program against any library and version we like, but
# they won't necessarily work on the particular X and driver combo that's in
# use (e.g. it's common to get 'missing symbol' errors when using OpenGL
# programs from one NixOS version on another).
#
# NixGL is a workaround which lets us inject a compatible drivers into a
# program's environment. This helper function lets us wrap programs with NixGL,
# such that they're always run with a compatible driver. For example:
#
#     pinGL {
#       nixpkgsRepo = repo1709;
#       pkg         = nixpkgs1709.firefox;
#       binaries    = [ "firefox" ];
#       gl          = "Intel";
#     }
#
# This defines a package whose 'bin/' dir contains a script for each entry in
# the 'binaries' argument; in this case 'firefox'. Each of these scripts is a
# wrapper around the corresponding 'bin/' entry of the 'pkg' argument; in this
# case '${nixpkgs1709.firefox}/bin/firefox'. These will be run with the nixGL
# wrapper specified by the 'gl' argument; in this case 'nixGLIntel'. The driver
# will be loaded from the nixpkgs repository given by 'nixpkgsRepo'; in this
# case 'repo1709'. Note that nixGL relies on nixpkgs overlays, which were only
# introduced in nixpkgs 17.03, so earlier repos will need to be sent through
# backportOverlays.
{ attrsToDirs', backportOverlays, coreutils, die, hasBinary, lib,
  nix-helpers-sources, nixpkgs1609, nixpkgs1803, patchShebang, repo1609,
  repo1803, runCommand, wrap }:

with lib;
with {
  nixGL = nix-helpers-sources.nixgl;
};
{
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
  wrappers    = mapAttrs (name: dir: patchShebang { inherit dir name; })
                         (import nixGL { pkgs = import nixpkgsRepo; });
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
      #!${coreutils}/bin/env bash
      exec "${wrapperName}" "${pkg}/bin/${name}" "$@"
    '';
  });
}
