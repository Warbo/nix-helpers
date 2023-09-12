# Extract a given tarball. If it's not a tarball, just copy.
{ runCommand }:

name: src:
runCommand name { inherit src; } ''
  isTar() {
    echo "$1" | grep -i '\.tar' 1>/dev/null && return 0
    echo "$1" | grep -i '\.tgz' 1>/dev/null && return 0
    return 1
  }

  if [[ -d "$src" ]]
  then
    cp -r "$src" "$out"
  else if isTar "$src"
    then
      # Extract top-level directory (whatever it's called) to $out
      mkdir "$out"
      tar xf "$src" -C "$out" --strip-components 1
    else
      cp -r "$src" "$out"
    fi
  fi
''
