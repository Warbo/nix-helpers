{ jq, lib, makeWrapper, nixListToBashArray, python, runCommand, withArgsOf,
  withDeps, writeScript }:

with builtins;
with lib;
with rec {
  checks = varChk // depChk;

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

  wrap = { paths ? [], vars ? {}, file ? null, script ? null, name ? "wrap" }:
    assert file != null || script != null ||
           abort "wrap needs 'file' or 'script' argument";
    with rec {
      f = if file == null then writeScript name script else file;

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
        inherit f;
        buildInputs = [ makeWrapper ];
      })
      ''
        ARGS=()

        echo "Getting paths" 1>&2
        ${pathData.code}
        for P in "''${pathVars[@]}"
        do
          ARGS=("''${ARGS[@]}" "--prefix" "PATH" ":" "$P/bin")
        done

        echo "Getting vars" 1>&2
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
};

args: withDeps (attrValues checks) (wrap args)
