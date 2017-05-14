# Runs 'cabal update' on an impure path, outside the Nix store
{ cabal-install, hackageDb, runCommand }:

path: runCommand "hackage-update"
  {
    # hackageDb isn't used by this derivation, but adding it as a dependency
    # causes our cache to expire at the same time, making cache expiry DRY
    inherit hackageDb;
    buildInputs = [ cabal-install ];
    HOME        = path;
  }
  ''
    # Whenever hackageDb expires, update HOME too
    [[ -d "$HOME" ]] || mkdir -p "$HOME"
    cabal update

    # Allow access to subsequent builders. Existing stuff may be owned by
    # others, which causes a bunch of errors. This is non-critical so we
    # ignore them all.
    chmod 777 -R "$HOME" 2>/dev/null || true

    # Maybe help debugging by knowing when we updated
    date > "$out"
  ''
