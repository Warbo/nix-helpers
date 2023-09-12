{ nixListToBashArray, runCmd }:

with nixListToBashArray {
  name = "check";
  args = [ "foo" ];
};
runCmd "check-NLTBA" env ''
  ${code}
  echo pass > "$out"
''
