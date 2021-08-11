{ backtrace, runCommand }:

runCommand "backtrace-test" { buildInputs = [ backtrace ]; } ''
  X=$(NOTRACE=1 backtrace)
  [[ -z "$X" ]] || {
    echo "NOTRACE should suppress trace" 1>&2
    exit 1
  }

  Y=$(backtrace)
  for Z in "Backtrace" "End Backtrace" "bash"
  do
    echo "$Y" | grep -F "$Z" || {
      echo "Didn't find '$Z'" 1>&2
      exit 1
    }
  done

  echo pass > "$out"
''
