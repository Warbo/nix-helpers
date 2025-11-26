#!/usr/bin/env bash
set -e

if [[ "x$1" == "x-h" ]] || [[ "x$1" == "x--help" ]] || [[ "x$1" == "x-?" ]]; then
  {
    echo "nix_release: Find and build all Nix derivations defined in a file"
    echo
    echo "Runs nix_release_eval to find all Nix derivations, then attempts"
    echo "to build each in turn. Reports how many succeed/fail at the end."
    echo
    echo "Any (optional) arguments will be passed to the build commands,"
    echo "which are 'nix-store --realise ...' (followed by each .drv)."
    echo
    echo "Set the ADD_ROOT env var to a directory path if you would like"
    echo "garbage collector roots to be created."
    echo
    echo "Set the F env var to the path you'd like to import. If F is not"
    echo "set, we default to looking for a ./release.nix file, then"
    echo "./nix/release.nix, then ./default.nix and finally"
    echo "./nix/default.nix; the first one found will be used, or we abort"
    echo "if none is found."
  } 1>&2
  exit 0
fi

if [[ -n $ADD_ROOT ]]; then
  [[ -e $ADD_ROOT ]] || fail "ADD_ROOT dir '$ADD_ROOT' doesn't exist"
  echo "GC roots will be made in '$ADD_ROOT'" 1>&2
else
  echo "Won't make GC roots. If you want them, give an \$ADD_ROOT dir" 1>&2
fi

DRVPATHS=$("$nix_release_eval") || fail "Failed to get paths, aborting"

function build {
  nix-store --show-trace --realise "$@"
}

echo "Building derivations" 1>&2
COUNT=0
FAILS=0
while read -r PAIR; do
  COUNT=$((COUNT + 1))
  ATTR=$(echo "$PAIR" | cut -f1)
  DRV=$(echo "$PAIR" | cut -f2)

  echo "Building $ATTR" 1>&2
  if [[ -n $ADD_ROOT ]]; then
    build --indirect --add-root "$ADD_ROOT/$ATTR" "$@" "$DRV" ||
      FAILS=$((FAILS + 1))
  else
    build "$@" "$DRV" ||
      FAILS=$((FAILS + 1))
  fi
done < <(echo "$DRVPATHS")

if [[ $FAILS -eq 0 ]]; then
  echo "All $COUNT built successfully" 1>&2
else
  printf '%s/%s builds failed\n' "$FAILS" "$COUNT" 1>&2
  exit 1
fi
