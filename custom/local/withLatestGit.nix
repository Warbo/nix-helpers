{ latestGit, lib, stdenv, substituteAll }:

with builtins;
with lib;

# Use latestGit as src for a derivation, cache the commit ID in the environment
{ url, ref ? "HEAD", refIsRev ? false, srcToPkg, resultComposes ? false }:

assert isFunction srcToPkg;
assert isString url;
assert isString ref;
assert isBool refIsRev;
assert isBool resultComposes;
assert refIsRev -> ref != "HEAD";

with rec {
  rawSource = latestGit { inherit url;
                          ref = if refIsRev then "" else ref; };
  source    = if refIsRev then stdenv.lib.overrideDerivation
                                 rawSource
                                 (old: { rev = ref; })
                          else rawSource;
  result    = srcToPkg source;
  hUrl      = builtins.hashString "sha256" url;
  hRef      = builtins.hashString "sha256" ref;
  rev       = if refIsRev then ref else source.rev;
};

assert isAttrs source;
assert hasAttr "rev" source;
assert isAttrs result || isFunction result;
assert resultComposes -> isFunction result;

with rec {
  cacheRev = p:
    assert isAttrs p;
    overrideDerivation p (old: {
      setupHook = substituteAll {
        src = ./nixGitRefs.sh;
        key = "${hUrl}_${hRef}";
        val = rev;
      };
    });
  drv = if isFunction result
           then if resultComposes
                   then result cacheRev
                   else args: cacheRev (result args)
           else cacheRev result;
};

assert isFunction result -> isFunction drv;
assert isAttrs    result -> isAttrs    drv;
drv
