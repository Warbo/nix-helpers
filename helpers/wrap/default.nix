{ bash, coreutils, hello, jq, lib, makeSetupHook, nixListToBashArray,
  pinnedNixpkgs, python, python3, runCommand, stdenv, patchShebang,
  writeScript }:

with builtins;
with lib;
with rec {
  # Load makeWrapper from 16.09 so that it has known behaviour w.r.t. quoting,
  # etc.
  makeWrapper = makeSetupHook {}
    "${pinnedNixpkgs.repo1609}/pkgs/build-support/setup-hooks/make-wrapper.sh";
};
{
  file          ? null,
  name,
  patchShebangs ? true,
  paths         ? [],
  script        ? null,
  vars          ? {}
}:
  assert file != null || script != null ||
         abort "wrap needs 'file' or 'script' argument";
  with rec {
    # If we're given a string, write it to a file. We put that file in a
    # directory since Python scripts can take a while to start if they live
    # directly in the Nix store (presumably from scanning for modules).
    inDir = runCommand "${name}-unwrapped"
      { f = writeScript "${name}-raw" (if patchShebangs
                                          then patchShebang {
                                                 string = script;
                                               }
                                          else script); }
      ''
        mkdir "$out"
        cp "$f" "$out/"${escapeShellArg name}
      '';

    newFile = "${inDir}/${name}";

    f = if file == null
           then newFile
           else if patchShebangs
                   then patchShebang { inherit file name; }
                   else file;

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
        REMAINING=("$P/nix-support/propagated-native-build-inputs" "$P/nix-support/propagated-build-inputs" )
        while [[ "''${#REMAINING[@]}" -gt 0 ]]
        do
          PROPS="''${REMAINING[0]}"
          REMAINING=("''${REMAINING[@]:1:''${#REMAINING[@]}}" )
          if [[ -e "$PROPS" ]]
          then
            while read -r PROP
            do
              ARGS=("''${ARGS[@]}" "--prefix" "PATH" ":" "$PROP/bin")
              MORE="$PROP/nix-support/propagated-native-build-inputs"
              if [[ -e "$MORE" ]]
              then
                REMAINING=("''${REMAINING[@]}" "$MORE")
              fi
              MORE="$PROP/nix-support/propagated-build-inputs"
              if [[ -e "$MORE" ]]
              then
                REMAINING=("''${REMAINING[@]}" "$MORE")
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
    ''
