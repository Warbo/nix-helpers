{ runCmd, unpack' }:

with {
  dir = runCmd "dir" {} ''
    mkdir "$out"
    echo "test" > "$out/foo.txt"
  '';

  tarball = runCmd "tarball.tar.gz" {} ''
    mkdir toplevelDir
    echo "test" > toplevelDir/foo.txt
    tar czf "$out" toplevelDir
  '';

  targz = runCmd "targz.tgz" {} ''
    mkdir toplevelDir
    echo "test" > toplevelDir/foo.txt
    tar czf "$out" toplevelDir
  '';
};
runCmd "check-unpack"
  {
    dir     = unpack' "dir"     dir;
    tarball = unpack' "tarball" tarball;
    targz   = unpack' "targz"   targz;
  }
  ''
    check() {
      echo "Checking $2" 1>&2
      [[ -d "$1" ]] || {
        echo "$1 isn't a directory" 1>&2
        exit 1
      }
      [[ -f "$1/foo.txt" ]] || {
        echo "Didn't find $1/foo.txt" 1>&2
        exit 1
      }
      F="$1/foo.txt"
      grep 'test' < "$F" > /dev/null || {
        echo "Expected to find 'test' in $F, got:" 1>&2
        cat "$F"
        exit 1
      }
      echo "$2 passed" 1>&2
    }

    check "$dir" "directory"
    check "$tarball" "tarball"
    check "$targz" "targz"
    echo "pass" > "$out"
  ''
