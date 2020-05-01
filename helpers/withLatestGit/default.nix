{ die, fail, getType, isCallable, latestGit, lib, runCommand, stdenv,
  substituteAll, withLatestGit, withNix, writeScript }:

with builtins;
with lib;

  # Use latestGit as src for a derivation, cache the commit ID in the environment
{
  ref            ? "HEAD",
  refIsRev       ? false,
  resultComposes ? false,
  srcToPkg,
  stable         ? {},
  url
}:

  assert isCallable srcToPkg || die {
    error = "srcToPkg must be callable";
    type  = getType srcToPkg;
  };
  assert isString url        || die {
    error = "url must be a string";
    type  = getType url;
  };
  assert isString ref || die {
    error = "ref must be a string";
    type  = getType ref;
  };
  assert isBool refIsRev || die {
    error = "refIsRev must be a boolean";
    type  = getType refIsRev;
  };
  assert isBool resultComposes || die {
    error = "resultComposes must be a boolean";
    type  = getType resultComposes;
  };
  assert refIsRev -> ref != "HEAD" || die {
    inherit refIsRev ref;
    error = "Need an explicit 'ref' (not HEAD) when used as a revision";
  };

  with rec {
    rawSource = latestGit { inherit url stable;
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

  assert isAttrs source || die {
    error = "source must be an attrset";
    type  = getType source;
  };
  assert source ? rev || die {
    error = "'source' must contain a 'rev'";
    attrs = attrNames source;
  };
  assert isAttrs result || isCallable result || die {
    error = "result must be an attrset or callable";
    type  = getType result;
  };
  assert resultComposes -> isCallable result || die {
    inherit resultComposes;
    error = "Can't compose since result isn't callable";
    type  = getType result;
  };

  with rec {
    cacheRev = p:
      assert isAttrs p || die {
        error = "cacheRev must be given an attrset";
        type  = getType p;
      };
      with { key = "${hUrl}_${hRef}"; };
      overrideDerivation p (old: rec {
        setupHook = substituteAll {
          inherit key;
          src = ./nixGitRefs;
          val = rev;
        };
        shellHook = ''
          nix_git_rev_${key}="${rev}"
          export nix_git_rev_${key}
        '';
      });
    drv = if isCallable result
             then if resultComposes
                     then result cacheRev
                     else args: cacheRev (result args)
             else cacheRev result;
  };

  assert isCallable result -> isCallable drv || die {
    error      = "drv should be callable";
    resultType = getType result;
    drvType    = getType drv;
  };
  assert isAttrs    result -> isAttrs    drv || die {
    error      = "drv should be attrset";
    resultType = getType result;
    drvType    = getType drv;
  };
  drv
