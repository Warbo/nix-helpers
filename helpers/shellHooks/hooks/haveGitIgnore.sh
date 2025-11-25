#!/usr/bin/env bash
(
	GIT_DIR=$(git rev-parse --show-toplevel) || exit 0
	[[ -e "$GIT_DIR/.gitignore" ]] || touch "$GIT_DIR/.gitignore"
)
