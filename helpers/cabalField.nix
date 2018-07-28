{ fail, haskellPackages, runCommand, unpack' }:

with builtins;
rec {
  def = { dir, field }:
    import (runCommand "cabal-field-${field}.nix"
             {
               inherit dir field;
               buildInputs = [ fail ];
             }
             ''
               set   -e
               set   -o pipefail
               shopt -s nullglob

               cd "$dir" || fail "Couldn't cd to '$dir'"

               VAL=""
               for F in *.cabal
               do
                 LINES=$(grep -i "^$field\s*:" < "$F") ||
                   fail "No '$field' lines in '$F'"

                 VAL=$(echo "$LINES" | head -n1       |
                                       cut -d ':' -f2 |
                                       sed -e 's/\s//g')
               done
               [[ -n "$VAL" ]] || {
                 echo "Couldn't find Cabal field '$field' in '$dir'" 1>&2
                 exit 1
               }
               echo "\"$VAL\"" > "$out"
             '');
  tests = runCommand "cabalField-test"
    {
      found = def {
        dir   = unpack' "text" haskellPackages.text.src;
        field = "name";
      };
    }
    ''
      [[ "x$found" = "xtext" ]] || {
        echo "Got '$found' instead of 'text'" 1>&2
        exit 1
      }
      mkdir "$out"
    '';
}
