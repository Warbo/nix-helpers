# Turns nested attribute sets into a single level, with dot-separated names.
{ die, hello, lib }:

with builtins;
with lib;
with rec {
  # Recurses through attrsets looking for derivations or non-attrsets. 'path'
  # keeps track of where we are in the overall structure.
  go = path: val:
    if !(isAttrs val) || isDerivation val
    # A leaf: use 'path' to make the attribute name and keep value as-is
    then {
      "${concatStringsSep "." path}" = val;
    }
    # An attrset: process every entry, appending their 'path' as needed, and
    # merge all results.
    else
      fold mergeAttrs { }
      (map (name: go (path ++ [ name ]) (getAttr name val)) (attrNames val));
};

# Only call 'go' if we've got an attrset (and hence 'path' makes sense)
val:
if !(isAttrs val) || isDerivation val then val else go [ ] val
