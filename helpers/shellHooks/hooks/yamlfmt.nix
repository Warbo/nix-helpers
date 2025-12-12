{ git, writeShellApplication }:
''
  (
    ${
      writeShellApplication {
        name = "yamlfmtHook";
        text = builtins.readFile ./yamlfmt;
        runtimeInputs = [ git ];
      }
    }/bin/yamlfmt
  )
''
