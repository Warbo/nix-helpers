{ git, writeShellApplication }:
''
  (
    ${
      writeShellApplication {
        name = "haveGitIgnoreHook";
        text = builtins.readFile ./haveGitIgnore;
        runtimeInputs = [ git ];
        runtimeEnv.PRESETS = builtins.toFile "gitignorePresets" ''
          /.pre-commit-config.yaml
          /.editorconfig
          /.yamlfmt
        '';
      }
    }/bin/haveGitIgnoreHook
  )
''
