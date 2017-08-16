# Builds a directory whose entries/content correspond to the names/values of
# the given attrset. When a value is an attrset, the corresponding entry is
# a directory, whose contents is generated with attrsToDirs on that value.
{ isPath, runCommand }:

with builtins;
with rec {
  toPaths = prefix: val:
    if isPath val || isDerivation val
       then [{ name  = prefix;
               value = val; }]
       else concatMap (entry: toPaths (prefix + "/" + entry)
                                      (getAttr entry val))
                      (attrNames val);

  toCmds = attrs:
    concatStringsSep "\n"
      ([''mkdir -p "$out"''] ++
       (map (entry: ''
               mkdir -p "$(dirname "${entry.name}")"
               ln -s "${entry.value}" "${entry.name}"
             '')
             (toPaths "$out" attrs)));
};

attrs: trace "FIXME: Use env vars instead of splicing" runCommand "merged" {} (toCmds attrs)
