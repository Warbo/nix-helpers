# A wrapper around the 'replace' command, which is simpler and saner. We used to
# use a binary from MariaDB but it's now removed, and it was a heavy dependency.
{ bash, die, fail, mkBin, runCommand, super }:

with builtins;
assert super ? replace || die {
  error = "No 'replace' in super.";
  names = attrNames super;
  inherit (super) src;
};
with rec {
  delim = x: "$" + "{" + x + "}";

  def   = mkBin {
    name   = "replace";
    paths  = [ bash fail ];
    script = ''
      #!/usr/bin/env bash
      set -e

      REPLACEMENTS=()
      FILES=()

      function nonEven {
        fail "Non-even number of replacement strings. Found string pairs '${
              delim "REPLACEMENTS[*]"}' and failed with leftovers '$*'."
      }

      function dodgy {
        # Check for strings beginning with "-" in case 'go' treats them as flags
        # FIXME: There should be a way to do this.
        if [[ "x${delim "1:0:1"}" = "x-" ]]
        then
          return 0
        else
          return 1
        fi
      }

      # Keep popping off pairs of strings, until we run out or hit "--"
      while [[ "$#" -gt 0 ]]
      do
        # "--" should only appear after a pair of strings, not a single string.
        if [[ "x$2" = "x--" ]]
        then
          nonEven
          exit 1 # Just in case
        fi

        # If we find "--" then shift it off and break the loop; any remaining
        # arguments will be treated as filenames.
        if [[ "x$1" = "x--" ]]
        then
          shift
          break
        fi

        # Shouldn't have a lone replacement string, even without "--"
        if [[ "$#" -lt 2 ]]
        then
          nonEven
          exit 1 # Just in case
        fi

        [[ -z "$1" ]] && fail "Can't replace empty string"
        dodgy "$1" && fail "Can't replace strings ($1) beginning with '-'"
        dodgy "$2" && fail "Can't insert strings ($2) beginning with '-'"

        # If we reach here we have another old/new pair of strings to replace
        if [[ "${delim "#REPLACEMENTS[@]"}" -gt 0 ]]
        then
          REPLACEMENTS=("${delim "REPLACEMENTS[@]"}" -a "$1" "$2")
        else
          # First pair doesn't need "-a" flag
          REPLACEMENTS=("${delim "REPLACEMENTS[@]"}"    "$1" "$2")
        fi
        shift
        shift
      done

      [[ "${delim "#REPLACEMENTS[@]"}" -gt 0 ]] || fail "No replacements given?"

      # Gather up remain args as filenames to process in-place
      while [[ "$#" -gt 0 ]]
      do
        dodgy "$1" && fail "Spotted dodgy argument '$1' (empty or '-')"
        FILES=("${delim "FILES[@]"}" "$1")
        shift
      done

      function go {
        # Do the actual replacement. The 'replace' command does the magic, but
        # we constrain its peculiar defaults:
        #   -e forces case sensitivity
        #   -s allows replacement anywhere, not just at "word boundaries"
        #   -f forces in-place replacement,
        "${super.replace}/bin/replace-literal" -e -s "$@"
      }

      if [[ "${delim "#FILES[@]"}" -eq 0 ]]
      then
        # No files, use stdio
        go "${delim "REPLACEMENTS[@]"}"
        exit 0
      else
        # Filenames given, replace them without backing up
        go -f "${delim "REPLACEMENTS[@]"}" "${delim "FILES[@]"}"
        exit 0
      fi
    '';
  };

  test = { args, name, pre, post }: runCommand "replace-test-${name}"
    { buildInputs = [ def fail ]; }
    ''
      ${pre}replace ${concatStringsSep " " args}${post}
      mkdir "$out"
    '';
};
{
  inherit def;
  tests = {
    die-odd-args = test {
      name = "die-old-args";
      args = [ "old1" "new1" "unpaired" ];
      pre  = "echo 'hello' | ";
      post = " && fail 'Should have died on odd args'";
    };
    replace-single-inplace = test {
      name = "single-stdin";
      args = [ "old" "new" "--" "f" ];
      pre  = ''
        echo "embolden" > f
      '';
      post = ''

        X=$(cat f)
        [[ "x$X" = "xembnewen" ]] || fail "Didn't replace, got:$X"
      '';
    };
    replace-two-stdin = test {
      name = "two-stdin";
      args = [ "foo" "bar" "baz" "quux" ];
      pre  = "X=$(echo -e 'fools are barred\nfrom bazinga' | ";
      post = ''
        )
        Y=$(echo -e 'barls are barred\nfrom quuxinga')
        [[ "x$X" = "x$Y" ]] || fail "No match:\n$X\n\n$Y"
      '';
    };
  };
}
