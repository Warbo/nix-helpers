# Builds a directory whose entries/content correspond to the names/values of
# the given attrset. When a value is an attrset, the corresponding entry is
# a directory, whose contents is generated with attrsToDirs on that value.
{ isPath, lib, nixListToBashArray, nothing, runCmd }:

with builtins;
with lib;
with rec {
  toPaths = prefix: val:
    if isPath val || isDerivation val
       then [{ name  = prefix;
               value = val; }]
       else if isAttrs val
               then concatMap (entry: toPaths (prefix + "/" + entry)
                                              (getAttr entry val))
                              (attrNames val)
               else abort "Unsupported type ${typeOf val} in attrsToDirs";
};
rec {
  pkg = attrs:
    with rec {
      # We can't have empty attr names, so always stick a dummy '_' at the start,
      # and strip it off in the build script
      data = listToAttrs (toPaths "_" attrs);

      # The element order of these lists is arbitrary, but they must match
      paths    = attrNames data;
      content  = map (n: getAttr n data) paths;

      # Create bash code and env vars for the build command, without forcing any
      # derivations to be built at eval time.
      pathData    = nixListToBashArray { name = "VALPATHS"; args = paths;   };
      contentData = nixListToBashArray { name = "VALUES";   args = content; };
    };
    if attrs == {}
       then nothing
       else runCmd "merged" (pathData.env // contentData.env) ''
              ${pathData.code}
              ${contentData.code}

              # Loop over each path/content entry in our arrays (off-by-one cruft
              # is due to seq preferring to count from 1)
              for NPLUSONE in $(seq 1 "''${#VALUES[@]}")
              do
                N=$(( NPLUSONE - 1 ))

                # The output path we're going to make; cut off leading _ and
                # prepend $out
                STRIPPED=$(echo "''${VALPATHS[$N]}" | cut -c 2-)
                       P="$out$STRIPPED"

                # Ensure parent directories exist
                mkdir -p "$(dirname "$P")"

                # Link value in place (saves space compared to copying)
                ln -s "''${VALUES[$N]}" "$P"
              done
            '';
  tests = pkg { foo = { bar = ./attrsToDirs.nix; }; };
}
