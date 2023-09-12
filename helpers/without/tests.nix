{ fail, hello, mupdf, runCommand, without }:

with builtins;
with rec {
  go = { label, pkg, toRemove }:
    runCommand "can-remove-${label}" {
      buildInputs = [ fail ];
      p = without pkg toRemove;
    } ''
      [[ -e "$p" ]] || fail "Dir '$p' not found"
      ${concatStringsSep "\n"
      (map (p: ''[[ -e "$p/${p}" ]] && fail "Didn't remove '$p/${p}'"'')
        toRemove)}
      mkdir "$out"
    '';
}; {
  canRemoveSimple = go {
    label = "simple-package";
    pkg = hello;
    toRemove = [ "bin/hello" ];
  };

  canRemoveMultiOutput = go {
    label = "multi-output-derivation";
    pkg = mupdf;
    toRemove = [ "bin/mupdf-gl" "bin/mupdf-x11-curl" ];
  };
}
