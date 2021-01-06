# Provides a 'backtrace' command showing the process hierarchy of its caller
{ bash, mkBin, runCommand }:

mkBin {
  name   = "backtrace";
  script = ''
    #!${bash}/bin/bash
    set -e

    [[ -z "$NOTRACE" ]] || exit 0

    [[ -d /proc ]] || {
      echo "No /proc found (not on Linux?), skipping backtrace" 1>&2
      exit 0
    }

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
}
