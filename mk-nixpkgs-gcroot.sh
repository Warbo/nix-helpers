#!/usr/bin/env bash
set -e

# Creates a Nix gcroot for the latest Nixpkgs, to prevent it getting deleted
# then downloaded over and over by the GC.
D=$(nix-instantiate --eval --read-write-mode -E '(import ./. {}).nixpkgs.path')
nix-store --add-root nixpkgs-gcroot -r "$D"
