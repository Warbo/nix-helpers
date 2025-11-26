#!/usr/bin/env bash
(
	GIT_DIR=$(git rev-parse --show-toplevel) || exit 0
	GI="$GIT_DIR/.gitignore"
	[[ -e $GI ]] || touch "$GI"

	for LINE in '/.pre-commit-config.yaml'; do
		grep -q -Fx "$LINE" <"$GI" ||
			printf '%s\n' "$LINE" >>"$GI"
	done
)
