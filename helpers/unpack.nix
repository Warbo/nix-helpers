# Extract a given tarball. If it's not a tarball, just copy.
{ runCommand }:

src: runCommand "unpack" { inherit src; } ''
  if [[ -d "$src" ]]
  then
    cp -r "$src" "$out"
  else if echo "$src" | grep '\.tar' 1>/dev/null
       then
         # Extract top-level directory (whatever it's called) to $out
         mkdir "$out"
         tar xf "$src" -C "$out" --strip-components 1
       else
         cp -r "$src" "$out"
       fi
  fi
''
