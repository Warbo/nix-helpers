{ bash, hello, jq, lib, python, python3, runCommand, stdenv, wrap, writeScript
}:

with lib;
with {
  # Make sure that derivations given as paths and vars aren't forced during
  # evaluation (only at build time)
  depChk = with {
    script = wrap {
      name = "depChk-script";
      vars = { broken1 = runCommand "broken1" { } "exit 1"; };
      paths = [ (runCommand "broken2" { } "exit 1") ];
      script = "exit 1";
    };
  }; {
    brokenDepsNotForced = runCommand "checkBrokenDepsNotForced" {
      val = if isString script.buildCommand then "true" else "false";
    } ''
      if "$val"
      then
        echo "pass" > "$out"
        exit 0
      fi
      exit 1
    '';

    haveDeps = runCommand "checkHaveDeps" {
      script = wrap {
        name = "haveDepsChecker";
        vars = {
          A = "foo";
          B = "hello world";
          C = "Single 'quotes'";
          D = ''Double "quotes"'';
        };
        paths = [ jq python ];
        script = ''
          #!${bash}/bin/bash
          command -v jq || {
            echo "No jq" 1>&2
            exit 1
          }

          command -v python || {
            echo "No python" 1>&2
            exit 1
          }

          [[ "x$A" = "xfoo" ]] || {
            echo "No A?" 1>&2
            env 1>&2
            exit 1
          }

          [[ "x$B" = "xhello world" ]] || {
            echo "No B?" 1>&2
            env 1>&2
            exit 1
          }

          [[ "x$C" = "xSingle 'quotes'" ]] || {
            echo "No C?" 1>&2
            env 1>&2
            exit 1
          }

          [[ "x$D" = 'xDouble "quotes"' ]] || {
            echo "No D?" 1>&2
            env 1>&2
            exit 1
          }

          echo "pass" > "$out"
        '';
      };
    } ''"$script"'';
  };

  # Try a bunch of strings with quotes, spaces, etc. and see if they survive
  varChk = mapAttrs (n: v:
    runCommand "wrap-escapes-${n}" {
      cmd = wrap rec {
        vars = { "${n}" = v; };
        name = "check-wrap-escaping-${n}";
        paths = [ python ];
        script = ''
          #!${python}/bin/python
          from os import getenv

          n   = '${n}'
          v   = """${v}"""
          msg = "'{0}' was '{1}' not '{2}'"
          env = getenv(n)

          assert env == v, msg.format(n, env, v)

          print 'true'
        '';
      };
    } ''"$cmd" > "$out"'') {
      SIMPLE = "simple";
      SPACES = "with some spaces";
      SINGLE = "withA'Quote";
      DOUBLE = ''withA"Quote'';
      MEDLEY = ''with" all 'of the" above'';
    };

  wrapChk = {
    # Ensure files and scripts don't get unneeded wrappers if no env is given
    unwrappedFile = runCommand "unwrappedFile" {
      val = wrap {
        name = "foo";
        file = writeScript "bar" "baz";
      };
    } ''
      [[ -e "$val" ]] || {
        echo "No such file '$val'" 1>&2
        exit 1
      }
      [[ -h "$val" ]] || {
        echo "Not a link '$val'" 1>&2
        exit 1;
      }
      echo pass > "$out"
    '';

    unwrappedScript = runCommand "unwrappedScript" {
      val = wrap {
        name = "foo";
        script = "bar";
      };
    } ''
      [[ -e "$val" ]] || {
        echo "No such file '$val'" 1>&2
        exit 1
      }
      [[ -h "$val" ]] || {
        echo "Not a link '$val'" 1>&2
        exit 1;
      }
      echo pass > "$out"
    '';
  };

  # Check that propagated dependencies get included
  propCheck = {
    oneLevel = runCommand "checkDirectPropagationOfWrappedDeps" {
      wrapped = wrap {
        name = "accessPropagated1";
        paths = [
          (stdenv.mkDerivation {
            name = "dummy";
            src = ./default.nix;
            propagatedBuildInputs = [ hello ];
            installPhase = ''mkdir "$out"'';
            unpackPhase = "true";
          })
        ];
        script = ''
          #!${bash}/bin/bash
          set -e
          command -v hello || {
            echo "Program 'hello' not found in PATH ($PATH)" 1>&2
            exit 1
          }
          echo "Found 'hello' command" 1>&2
          exit 0
        '';
      };
    } ''
      "$wrapped" || exit 1
      mkdir "$out"
    '';

    nested = runCommand "checkNestedPropagationOfWrappedDeps" {
      wrapped = wrap {
        name = "accessPropagated2";
        paths = [
          (stdenv.mkDerivation {
            name = "dummy1";
            src = ./default.nix;
            propagatedBuildInputs = [
              (stdenv.mkDerivation {
                name = "dummy2";
                src = ./default.nix;
                propagatedBuildInputs = [
                  (stdenv.mkDerivation {
                    name = "dummy3";
                    src = ./default.nix;
                    propagatedBuildInputs = [ hello ];
                    installPhase = ''mkdir "$out"'';
                    unpackPhase = "true";
                  })
                ];
                installPhase = ''mkdir "$out"'';
                unpackPhase = "true";
              })
            ];
            installPhase = ''mkdir "$out"'';
            unpackPhase = "true";
          })
        ];
        script = ''
          #!${bash}/bin/bash
          set -e
          command -v hello || {
            echo "Program 'hello' not found in PATH ($PATH)" 1>&2
            exit 1
          }
          echo "Found 'hello' command" 1>&2
          exit 0
        '';
      };
    } ''
      "$wrapped" || exit 1
      mkdir "$out"
    '';
  };
};
varChk // depChk // wrapChk // propCheck // {
  wrap-test = wrap {
    name = "wrap-test";
    paths = [ bash ];
    vars = { MY_VAR = "MY VAL"; };
    script = ./default.nix;
  };

  python-test = runCommand "wrap-python-test" {
    script = wrap {
      name = "wrap-python-test.py";
      paths = [ python3 ];
      script = ''
        #!${python3}/bin/python3
        from subprocess import Popen, PIPE
        p = Popen(['cat'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        i = b'foo'
        (sout, serr) = p.communicate(i)
        assert sout.strip() == i, repr({
          'error'  : 'Output of cat did not match input',
          'input'  : i,
          'stdout' : sout,
          'stderr' : serr
        })
      '';
    };
  } ''
    "$script" || {
      echo "Wrapped Python script failed" 1>&2
      exit 1
    }
    mkdir "$out"
  '';
}
