# Augment the environment for a derivation by allowing Nix commands to be
# called inside the build process

{ isBroken, lib, nix,
  nix-daemon-tunnel-socket ? "/var/lib/nix-daemon-tunnel/socket", runCommand }:

with builtins;
with lib;
with import ./util.nix { inherit lib; };
with rec {
  # Our Nix 2.x workaround won't work unless the user creates the needed socket,
  # either manually or by enabling a service, so we warn them in two ways:
  #  - We check, during evaluation, whether the socket exists. If not, we write
  #    this warning to stderr using 'trace'.
  #  - We also add this warning to the environment variables we return, so that
  #    it's likely to be found by users debugging a broken build.
  warn =
    with rec {
      default = "/nix/var/nix/daemon-socket/socket";
      warning = evalTime: ''
        WARNING: Nix 2.x disabled recursive Nix, so we're using a hacky
        workaround where recursive connections to nix-daemon (i.e. those coming
        from nixbld users) are sent to a different socket instead, and an SSH
        tunnel passes them on to the real nix-daemon socket as a different user.

        This tunnel socket should be at the path '${nix-daemon-tunnel-socket}',
        which can be overridden by defining 'nix-daemon-tunnel-socket' in your
        Nix config (overlays, packageOverrides, etc.). You are seeing this
        message because ${
          if evalTime
             then ''
               the 'withNix' Nix expression checked for the existence of this
               socket during evaluation and it didn't exist.
             ''
             else ''
               this build environment was defined using 'withNix', and hence may
               need this socket to be created in order for the build to succeed.
             ''}

        There are two ways you can make this extra socket. To just make a
        one-off socket you can run a command like the following from your normal
        user account (assuming that nix-daemon is using a socket at ${default}):

          ssh -nNT -L "${nix-daemon-tunnel-socket}":${default} "$USER"@localhost
          chmod 0666 "${nix-daemon-tunnel-socket}"

        You may need to use 'sudo' to create and chmod this file. Keep this
        tunnel running while you perform Nix commands that need 'withNix'. Note
        that it's using SSH to log in as yourself, so it assumes that (a) your
        system/user can initiate SSH connections and (b) your user is able to
        log in via SSH.

        The alternative, which is more automated but potentially more invasive,
        is to provide this socket via a NixOS system service. The nix-config
        project at http://chriswarbo.net/git/nix-config provides such a service
        in its nixos/modules/nix-daemon-tunnel.nix file (if it's no longer
        there, try looking in the project's git history; it may be that the
        workaround is no longer needed, and Nix versions which require it are
        now obsolete).

        If you use the system service, note that the tunnel won't be available
        the first time you use 'nixos-rebuild' to evaluate and build the new
        system configuration. If your configuration relies on 'withNix', e.g.
        for building a system package, you can use the "manual" commands above
        to make the rebuild work then kill those commands in favour of the
        system service.
      '';
    };
    {
      WITH_NIX_WARNING = if pathExists nix-daemon-tunnel-socket
                            then                      warning false
                            else trace (warning true) warning false;
    };

  # Calculate what value to use for the NIX_REMOTE env var, and also add the
  # above warning to the environment if needed.
  remote =
    with rec {
      daemon = elem (getEnv "NIX_REMOTE") [ "" "daemon" ];
      tunnel = daemon && needWorkaround;
    };
    (if tunnel then warn else {}) // {
      NIX_REMOTE = if tunnel
                      then "unix://${nix-daemon-tunnel-socket}"
                      else if daemon then "daemon" else getEnv "NIX_REMOTE";
    };

  vars = remote // {
    NIX_PATH = if getEnv "NIX_PATH" == ""
                  then "nixpkgs=${<nixpkgs>}"
                  else getEnv "NIX_PATH";
  };
};
attrs: vars // attrs // {
  buildInputs = (attrs.buildInputs or []) ++ [ (nix.out or nix) ];

  # We need to access the tunnel file
  __noChroot = true;
}
