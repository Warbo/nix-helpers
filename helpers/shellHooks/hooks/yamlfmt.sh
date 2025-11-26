#!/usr/bin/env bash
(
  GIT_DIR=$(git rev-parse --show-toplevel) || exit 0
  YF="$GIT_DIR/.yamlfmt"

  if git check-ignore "$YF" >/dev/null; then
    [[ -e $YF ]] || {
      echo "Creating '$YF'" 1>&2
      touch "$YF"
    }

    # Increases compatibility with yamllint. Also tries to avoid long lines, but
    # that is a bit fuzzy, so we say 70 in the hope that it will be under 80:
    # https://github.com/google/yamlfmt/issues/191
    pattern=$(printf '%s\n  %s\n  %s\n  %s\n  %s\n  %s\n  %s' \
      'formatter:' \
      'type: basic' \
      'include_document_start: true' \
      'retain_line_breaks_single: true' \
      'max_line_length: 70' \
      'drop_merge_tag: true' \
      'pad_line_comments: 2')
    printf '%s\n' "$pattern" >"$YF"
  fi
)
