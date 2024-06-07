# Run a command in a Debian chroot which has the given packages installed
{
  bash,
  cacert,
  die,
  fetchurl,
  getType,
  lib,
  nix-helpers-sources,
  proot,
  runCommand,
  wrap,
  writeScript,
}:

with builtins;
with lib;
with rec {
  rootfs = nix-helpers-sources.debian-image;

  # See https://github.com/proot-me/PRoot/issues/106
  PROOT_NO_SECCOMP = "1";

  env =
    {
      debs,
      pkgs,
      post,
      pre,
      rootfs,
    }:
    runCommand "debian-chroot"
      {
        inherit rootfs PROOT_NO_SECCOMP;
        buildInputs = [ proot ];
        __noChroot = true;
        SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        script = writeScript "setup.sh" ''
          #!${bash}/bin/bash
          set -e

          # Preprocessing
          ${pre}
          # End preprocessing

          # Install packages
          apt-get update
          ${concatStringsSep "\n" (map (p: "apt-get install -y ${p}") pkgs)}
          while read -r P
          do
            dpkg -i "$P"
          done < <(find /root -maxdepth 1 -type f -name '*.deb' | sort -n)

          # Postprocessing
          ${post}
          # End postprocessing
        '';
      }
      ''
        echo "Unpacking Debian" 1>&2
        mkdir "$out"
        pushd "$out"
          tar xf "$rootfs"
        popd

        echo "Installing setup script" 1>&2
        cp "$script" "$out/setup.sh"

        echo "Pointing PATH to binary locations" 1>&2
        export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

        echo "Resetting /tmp variables" 1>&2
        export TMPDIR=/tmp
        export TEMPDIR=/tmp
        export TMP=/tmp
        export TEMP=/tmp

        if [[ ${toString (length debs)} -gt 0 ]]
        then
          echo "Copying across .debs" 1>&2
          COUNT=0
          ${
            concatStringsSep "\n" (
              map (f: ''
                cp "${f}" "$out/root/$COUNT.deb"
                COUNT=$(( COUNT + 1 ))
              '') debs
            )
          }
        fi

        echo "Setting up" 1>&2
        proot -r "$out" -b /proc -b /dev -0 /setup.sh
      '';
};
{
  binds ? [
    "/dev"
    "/home"
    "/nix"
    "/proc"
    "/run"
    "/tmp"
  ],
  debs ? [ ],
  pkgs ? [ ],
  post ? "",
  pre ? "",
  rootfs,
}:
assert
  isList pkgs
  || die {
    error = "Expected 'pkgs' to be a list of package names";
    type = typeOf pkgs;
  };
assert
  all isString pkgs
  || die {
    error = "Expected package names in 'pkgs' to be strings";
    types = map typeOf pkgs;
  };
assert
  isList debs
  || die {
    error = "Expected 'debs' to be a list of .deb files";
    type = typeOf debs;
  };
assert
  all (
    f:
    elem (getType f) [
      "derivation"
      "path"
    ]
  ) debs
  || die {
    error = "Expected each of 'debs' to be a derivation or path to a .deb file";
    types = map getType debs;
  };
wrap {
  name = "in-debian-chroot";
  paths = [
    bash
    proot
  ];
  vars = {
    inherit PROOT_NO_SECCOMP;
    env = env {
      inherit
        debs
        rootfs
        pkgs
        post
        pre
        ;
    };
  };
  script = ''
    #!${bash}/bin/bash
    export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"
    export TMPDIR=/tmp
    export TEMPDIR=/tmp
    export TMP=/tmp
    export TEMP=/tmp

    # shellcheck disable=SC2154
    proot -r "$env" ${concatStringsSep " " (map (b: "-b " + b) binds)} "$@"
  '';
}
