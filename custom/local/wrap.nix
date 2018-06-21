{ bash, hello, jq, lib, makeSetupHook, nixListToBashArray, python, repo1609,
  runCommand, stdenv, withArgsOf, withDeps, writeScript }:

with builtins;
with lib;
with rec {
  # Load makeWrapper from 16.09 so that it has known behaviour w.r.t. quoting,
  # etc.
  makeWrapper = makeSetupHook {} "${repo1609}/pkgs/build-support/setup-hooks/make-wrapper.sh";

  checks = varChk // depChk // wrapChk // propCheck;

  # Make sure that derivations given as paths and vars aren't forced during
  # evaluation (only at build time)
  depChk =
    with {
      script = wrap {
        vars = {
          broken1 = runCommand "broken1" {} "exit 1";
        };

        paths = [ (runCommand "broken2" {} "exit 1") ];

        script = "exit 1";
      };
    };
    {
      brokenDepsNotForced = runCommand "checkBrokenDepsNotForced"
        {
          val = if isString script.buildCommand then "true" else "false";
        }
        ''
          if "$val"
          then
            echo "pass" > "$out"
            exit 0
          fi
          exit 1
        '';

      haveDeps = runCommand "checkHaveDeps"
        {
          script = wrap {
            name   = "haveDepsChecker";
            vars   = {
              A = "foo";
              B = "hello world";
              C = "Single 'quotes'";
              D = ''Double "quotes"'';
            };
            paths  = [ jq python ];
            script = ''
              #!/usr/bin/env bash
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
        }
        ''"$script"'';
    };

  # Try a bunch of strings with quotes, spaces, etc. and see if they survive
  varChk = mapAttrs (n: v: runCommand "wrap-escapes-${n}"
                             {
                               cmd = wrap rec {
                                 vars   = { "${n}" = v; };
                                 name   = "check-wrap-escaping-${n}";
                                 paths  = [ python ];
                                 script = ''
                                   #!/usr/bin/env python
                                   from os import getenv

                                   n   = '${n}'
                                   v   = """${v}"""
                                   msg = "'{0}' was '{1}' not '{2}'"
                                   env = getenv(n)

                                   assert env == v, msg.format(n, env, v)

                                   print 'true'
                                 '';
                               };
                             }
                             ''"$cmd" > "$out"'')
                    {
                      SIMPLE = "simple";
                      SPACES = "with some spaces";
                      SINGLE = "withA'Quote";
                      DOUBLE = ''withA"Quote'';
                      MEDLEY = ''with" all 'of the" above'';
                    };

  wrapChk = {
    # Ensure files and scripts don't get unneeded wrappers if no env is given
    unwrappedFile = runCommand "unwrappedFile"
      {
        val = wrap { name = "foo"; file = writeScript "bar" "baz"; };
      }
      ''
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

    unwrappedScript = runCommand "unwrappedScript"
      {
        val = wrap { name = "foo"; script = "bar"; };
      }
      ''
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
    oneLevel = runCommand "checkDirectPropagationOfWrappedDeps"
      {
        wrapped = wrap {
          name   = "accessPropagated1";
          paths  = [
            (stdenv.mkDerivation {
              name                  = "dummy";
              src                   = ./wrap.nix;
              propagatedBuildInputs = [ hello ];
              installPhase          = ''mkdir "$out"'';
              unpackPhase           = "true";
            })
          ];
          script = ''
            #!/usr/bin/env bash
            set -e
            command -v hello || {
              echo "Program 'hello' not found in PATH ($PATH)" 1>&2
              exit 1
            }
            echo "Found 'hello' command" 1>&2
            exit 0
          '';
        };
      }
      ''
        "$wrapped" || exit 1
        mkdir "$out"
      '';

    nested = runCommand "checkNestedPropagationOfWrappedDeps"
      {
        wrapped = wrap {
          name   = "accessPropagated2";
          paths  = [
            (stdenv.mkDerivation {
              name                  = "dummy1";
              src                   = ./wrap.nix;
              propagatedBuildInputs = [
                (stdenv.mkDerivation {
                  name                  = "dummy2";
                  src                   = ./wrap.nix;
                  propagatedBuildInputs = [
                    (stdenv.mkDerivation {
                      name                  = "dummy3";
                      src                   = ./wrap.nix;
                      propagatedBuildInputs = [ hello ];
                      installPhase          = ''mkdir "$out"'';
                      unpackPhase           = "true";
                    })
                  ];
                  installPhase          = ''mkdir "$out"'';
                  unpackPhase           = "true";
                })
              ];
              installPhase          = ''mkdir "$out"'';
              unpackPhase           = "true";
            })
          ];
          script = ''
            #!/usr/bin/env bash
            set -e
            command -v hello || {
              echo "Program 'hello' not found in PATH ($PATH)" 1>&2
              exit 1
            }
            echo "Found 'hello' command" 1>&2
            exit 0
          '';
        };
      }
      ''
        "$wrapped" || exit 1
        mkdir "$out"
      '';
  };

  wrap = { paths ? [], vars ? {}, file ? null, script ? null, name ? "wrap" }:
    assert file != null || script != null ||
           abort "wrap needs 'file' or 'script' argument";
    with rec {
      f = if file == null then writeScript name script else file;

      # Whether any extra env vars or paths are actually needed
      needEnv = if paths == [] && vars == {}
                   then "false"
                   else "true";

      # Store each path in a variable pathVarN
      pathData = nixListToBashArray { name = "pathVars"; args = paths; };

      # Store each name in a variable varNamesN and the corresponding value in a
      # variable varValsN. Their order is arbitrary, but must match up.
      varNames    = attrNames vars;
      varNameData = nixListToBashArray {
        name = "varNames";
        args = varNames;
      };
      varValData  = nixListToBashArray {
        name = "varVals";
        args = map (n: getAttr n vars) varNames;
      };
    };
    runCommand name
      (pathData.env // varNameData.env // varValData.env // {
        inherit f needEnv;
        buildInputs = [ makeWrapper ];
      })
      ''
        # Shortcut if no extra env, etc. is needed
        $needEnv || {
          ln -s "$f" "$out"
          exit
        }

        ARGS=()

        ${pathData.code}
        for P in "''${pathVars[@]}"
        do
          # Add $P/bin to $PATH
          ARGS=("''${ARGS[@]}" "--prefix" "PATH" ":" "$P/bin")

          # We want 'paths' to act like 'buildInputs', so we also add any paths
          # from 'propagated build inputs'
          TODOS=("$P/nix-support/propagated-native-build-inputs" "$P/nix-support/propagated-build-inputs" )
          while [[ "''${#TODOS[@]}" -gt 0 ]]
          do
            PROPS="''${TODOS[0]}"
            TODOS=("''${TODOS[@]:1:''${#TODOS[@]}}" )
            if [[ -e "$PROPS" ]]
            then
              while read -r PROP
              do
                ARGS=("''${ARGS[@]}" "--prefix" "PATH" ":" "$PROP/bin")
                MORE="$PROP/nix-support/propagated-native-build-inputs"
                if [[ -e "$MORE" ]]
                then
                  TODOS=("''${TODOS[@]}" "$MORE")
                fi
                MORE="$PROP/nix-support/propagated-build-inputs"
                if [[ -e "$MORE" ]]
                then
                  TODOS=("''${TODOS[@]}" "$MORE")
                fi
              done < <(tr ' ' '\n' < "$PROPS")
            fi
          done
        done

        ${varNameData.code}
        ${ varValData.code}

        # Loop through the indices of each name/value; this is slightly awkward
        # since 'seq' likes to count from 1, but bash arrays start at 0.
        for NPLUSONE in $(seq 1 "''${#varNames[@]}")
        do
          N=$(( NPLUSONE - 1 ))

          # makeWrapper doesn't escape properly, so spaces, quote marks, dollar
          # signs, etc. will cause errors. Given a value FOO, makeWrapper will
          # write out a script containing "FOO" (i.e. it wraps the text in
          # double quotes). Double quotes aren't safe in Bash, since they splice
          # in variables for dollar signs, etc. Plus, makeWrapper isn't actually
          # doing any escaping: if our text contains a ", then it will appear
          # verbatim and break the surrounding quotes.
          # To work around this we do the following:
          #  - Escape all single quotes in our value using sed; this is made
          #    more awkward since we're using single-quoted Nix strings...
          #  - Surround this escaped value in single quotes, hence making a
          #    fully escaped text value which won't mess up any content
          #  - Surround this single-quoted-and-escaped value in double quotes.
          #    These "cancel out" the double quotes added by makeWrapper, i.e.
          #    instead of FOO -> "FOO", we do "FOO" -> ""FOO"", and hence the
          #    value FOO (in this case, our single-quoted-escaped-value) appears
          #    OUTSIDE the double quotes, and is hence free to use single quotes

          # Pro tip to any readers: try to avoid unintended string
          # interpretation wherever you can. Instead of "quoting variables where
          # necessary", you should always quote all variables; instead of
          # embedding raw strings into generated scripts and sprinkling around
          # some quote marks, you should always escape them properly (in Bash,
          # this is done by escaping single quotes wrapping in single quotes);
          # never treat double quotes as an escaping mechanism.


          # These vars make escaping slightly less crazy (Bash single-quote
          # escaping requires adjacent single-quotes, but we're in a Nix string
          # that's enclosed in double single-quotes... sigh)
          BS='\'
           T="'"

          ESC=$(echo "''${varVals[$N]}" | sed -e "s/$T/$T$BS$BS$T$T/g")

          ARGS=("''${ARGS[@]}" "--set" "''${varNames[$N]}" "\"'$ESC'\"")
        done

        makeWrapper "$f" "$out" "''${ARGS[@]}"
      '';

  go = args: withDeps (attrValues checks) (wrap args);
};
{
  pkg   = go;
  tests = checks // {
    wrap = go {
      name   = "wrap-test";
      paths  = [ bash ];
      vars   = {
        MY_VAR = "MY VAL";
      };
      script = ./wrap.nix;
    };
  };
}
