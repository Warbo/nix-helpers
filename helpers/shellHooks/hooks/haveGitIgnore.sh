#!/usr/bin/env bash
(
  GIT_DIR=$(git rev-parse --show-toplevel) || exit 0
  GI="$GIT_DIR/.gitignore"
  [[ -e $GI ]] || {
    echo "Creating '$GI'" 1>&2
    touch "$GI"
  }

  PRESETS=()
  PRESETS+=('/.pre-commit-config.yaml')
  PRESETS+=('/.editorconfig')
  PRESETS+=('/.yamlfmt')
  for LINE in "${PRESETS[@]}"; do
    grep -q -Fx "$LINE" <"$GI" ||
      printf '%s\n' "$LINE" >>"$GI"
  done
)
