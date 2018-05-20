# Provides a 'backtrace' command showing the process hierarchy of its caller
{ mkBin, runCommand }:

rec {
  pkg = mkBin {
    name   = "backtrace";
    script = ''
      #!/usr/bin/env bash
      set -e

      [[ -z "$NOTRACE" ]] || exit 0

      echo "Begin Backtrace:"

      ID="$$"  # Current PID
      while [[ "$ID" -gt 1 ]]  # Loop until we reach init
      do
        # Show this PID's
        cat "/proc/$ID/cmdline" | tr '\0' ' '
        echo

        # Get parent's PID
        ID=$(grep PPid < "/proc/$ID/status" | cut -d ':' -f2  |
                                              sed -e 's/\s//g')
      done

      echo "End Backtrace"
    '';
  };
  tests = [
    (runCommand "backtrace-test"
      { buildInputs = [ pkg ]; }
      ''
        X=$(NOTRACE=1 backtrace)
        [[ -z "$X" ]] || {
          echo "NOTRACE should suppress trace" 1>&2
          exit 1
        }

        Y=$(backtrace)
        for Z in "Backtrace" "End Backtrace" "bash"
        do
          echo "$Y" | grep -F "$Z" || fail "Didn't find '$Z'"
        done

        echo pass > "$out"
      '')
  ];
}
