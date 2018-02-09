#!/usr/bin/env bash
set -e

# Simple, quick sanity check. Useful as a git pre-commit hook.
nix-instantiate --show-trace --read-write-mode --eval \
  -E 'with builtins; all isAttrs (attrValues (import ./release.nix))'
