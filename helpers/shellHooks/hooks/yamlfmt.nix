{ git, writeShellApplication }:
''
  (
    ${
      writeShellApplication {
        name = "yamlfmtHook";
        text = builtins.readFile ./yamlfmt;
        runtimeInputs = [ git ];
        # Increases compatibility with yamllint. Also tries to avoid long lines,
        # but that is a bit fuzzy, so we say 70 in the hope that it will be
        # under 80: https://github.com/google/yamlfmt/issues/191
        runtimeEnv.DEFAULT = builtins.toFile "yamlfmt.conf" ''
          formatter:
            type: basic
            include_document_start: true
            retain_line_breaks_single: true
            max_line_length: 70
            drop_merge_tag: true
            pad_line_comments: 2
        '';
      }
    }/bin/yamlfmtHook
  )
''
