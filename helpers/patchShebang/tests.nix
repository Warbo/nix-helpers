{ attrsToDirs', coreutils, dummyBuild, fail, patchShebang, runCommand,
  writeScript }:

{
  dir = runCommand "patch-dir-shebangs"
    rec {
      buildInputs = [ fail ];
      input       = attrsToDirs' "shebang-dir" {
        foo = writeScript "test-foo" ''
          #!/usr/bin/env foo
          #!/usr/bin/env foo
        '';
        bar = writeScript "test-bar" ''
          #! /usr/bin/env bar
          #! /usr/bin/env bar
        '';
      };
      got = patchShebang { dir = input; };
    }
    ''
      for X in foo bar
      do
        [[ -e "$got/$X" ]] || fail "No '$got/$X' found"
        head -n 1 < "$got/$X" |
          grep "^#! *${coreutils}/bin/env $X" > /dev/null ||
          fail "Didn't spot coreutils shebang in '$got/$X'"
        tail -n 1 < "$got/$X" |
          grep "^#! */usr/bin/env $X" > /dev/null ||
          fail "Second shebang wasn't preserved in '$got/$X'"
      done
      mkdir "$out"
    '';

  string =
    with rec {
      input = ''
        #! /usr/bin/env foo
        #! /usr/bin/env bar
      '';
      want = ''
        #! ${coreutils}/bin/env foo
        #! /usr/bin/env bar
      '';
      got = patchShebang { string = input; };
    };
    assert want == got || die {
      inherit input want got;
      error = "Repaced shebangs didn't match expected";
    };
    dummyBuild "patch-string-shebang";
}
