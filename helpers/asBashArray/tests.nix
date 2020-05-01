{ asBashArray, fail, runCommand }:

{
  bashReadsArray = runCommand "test-as-bash-array"
    { buildInputs = [ fail ]; }
    ''
        DATA=${asBashArray [ "simple" "with space" "'single quoted'"
                             ''"double quoted"'' ''"mix ed''''' ]}
        COUNT=0
        for X in "''${DATA[@]}"
        do
          echo "Counting '$X'" 1>&2
          COUNT=$(( COUNT + 1 ))
        done
        [[ "$COUNT" -eq 5 ]] || fail "Counted '$COUNT', should have 5"
        mkdir "$out"
      '';
}
