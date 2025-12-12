{ git, writeShellApplication }:
''
  (
    ${
      writeShellApplication {
        name = "haveGitIgnoreHook";
        text = builtins.readFile ./haveGitIgnore;
        runtimeInputs = [ git ];
      }
    }/bin/haveGitIgnore
  )
''
