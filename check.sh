#!/usr/bin/env bash
set -e

# Simple, quick sanity check. Useful as a git pre-commit hook.

find . -name "*.nix" | while read -r F
do
    echo "Checking syntax of '$F'" 1>&2
    nix-instantiate --parse "$F" > /dev/null
done

echo "Checking we can evaluate all test derivations" 1>&2
nix-instantiate --show-trace \
                -E 'with import ./.; allDrvsIn nix-helpers-tests' || {
    echo "Couldn't evaluate all test derivations" 1>&2
    exit 1
}
