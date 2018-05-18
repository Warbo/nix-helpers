#!/usr/bin/env bash
set -e

# Simple, quick sanity check. Useful as a git pre-commit hook.
find . -name "*.nix" | while read -r F
do
    P=$(readlink -f "$F")
    echo "Checking '$P'" 1>&2
    nix-instantiate --show-trace --read-write-mode --eval \
                    -E "with builtins; typeOf (import $P)" > /dev/null
done
