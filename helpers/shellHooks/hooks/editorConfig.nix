{ git, writeShellApplication }:
''
  (
    ${
      writeShellApplication {
        name = "editorConfigHook";
        text = builtins.readFile ./editorConfig;
        runtimeInputs = [ git ];
        runtimeEnv.DEFAULT = builtins.toFile "editorconfig" ''
          [[shell]]
          indent_style = space
          indent_size = 2
          charset = utf-8
          simplify = true
        '';
      }
    }/bin/editorConfigHook
  )
''
