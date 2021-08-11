{ backtrace, runCommand }:

runCommand "backtrace-test" { buildInputs = [ backtrace ]; } ''
  X=$(NOTRACE=1 backtrace)
  [[ -z "$X" ]] || {
    echo "NOTRACE should suppress trace" 1>&2
    exit 1
  }

  if backtrace 2>&1 >/dev/null | grep -F 'No /proc found' > /dev/null
  then
    echo "Not testing backtraces on non-Linux system" 1>&2
  else
    Y=$(backtrace)

    for Z in "Backtrace" "End Backtrace" "bash"
    do
      echo "$Y" | grep -F "$Z" || {
        echo "Didn't find '$Z'" 1>&2
        exit 1
      }
    done
  fi

  echo pass > "$out"
''
