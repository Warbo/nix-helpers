#!/usr/bin/env bash
set -e

if [[ -z "$ADD_ROOT" ]]
then
    [[ -e "$ADD_ROOT" ]] || fail "ADD_ROOT dir '$ADD_ROOT' doesn't exist"
    echo "GC roots will be made in '$ADD_ROOT'" 1>&2
else
    echo "Won't make GC roots. If you want them, give an \$ADD_ROOT dir" 1>&2
fi

DRVPATHS=$("$nix_release_eval") ||  fail "Failed to get paths, aborting"

function build {
    nix-store --show-trace --realise "$@"
}

echo "Building derivations" 1>&2
COUNT=0
FAILS=0
while read -r PAIR
do
    COUNT=$(( COUNT + 1 ))
     ATTR=$(echo "$PAIR" | cut -f1)
      DRV=$(echo "$PAIR" | cut -f2)

    echo "Building $ATTR" 1>&2
    if [[ -z "$ADD_ROOT" ]]
    then
        build                                         "$@" "$DRV" ||
            FAILS=$(( FAILS + 1 ))
    else
        build --indirect --add-root "$ADD_ROOT/$ATTR" "$@" "$DRV" ||
            FAILS=$(( FAILS + 1 ))
    fi
done < <(echo "$DRVPATHS")

if [[ "$FAILS" -eq 0 ]]
then
    echo "All $COUNT built successfully" 1>&2
else
    printf '%s/%s builds failed\n' "$FAILS" "$COUNT" 1>&2
    exit 1
fi
