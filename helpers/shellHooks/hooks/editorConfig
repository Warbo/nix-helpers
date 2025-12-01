#!/usr/bin/env bash
(
  GIT_DIR=$(git rev-parse --show-toplevel) || exit 0
  EC="$GIT_DIR/.editorconfig"

  if git check-ignore "$EC" >/dev/null; then
    [[ -e $EC ]] || {
      echo "Creating '$EC'" 1>&2
      touch "$EC"
    }

    pattern=$'[[shell]]\nindent_style = space\nindent_size = 2'
    printf '%s\n' "$pattern" >"$EC"
  fi
)
