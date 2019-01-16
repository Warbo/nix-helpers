{ die, fail, getType, isCallable, latestGit, lib, runCommand, stdenv,
  substituteAll, withLatestGit, withNix, writeScript }:

with builtins;
with lib;
rec {
  # Use latestGit as src for a derivation, cache the commit ID in the environment
  def = {
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
    drv;

  tests =
    with {
      expr = ''import "${writeScript "withLatestGit-example.nix" ''
        with import ${./..};
        withLatestGit {
          url      = "http://chriswarbo.net/git/nix-helpers.git";
          srcToPkg = x: x;
        }''}"'';
    };
    runCommand "test-withLatestGit"
      (withNix { buildInputs = [ fail ]; })
      ''
        echo "Checking if nix_git_rev_... is set inside nix-shell" 1>&2
        CODE=0
        OUTPUT=$(nix-shell --show-trace -E '${expr}' --run 'env') ||
          fail "Failed to run nix-shell: $OUTPUT"

        echo "$OUTPUT" | grep "^nix_git_rev_" > /dev/null ||
          fail "No nix_git_rev_... variables were set: $OUTPUT"

        echo "Shell environment contained nix_git_rev_... variable" 1>&2

        echo "Running nested nix-shells" 1>&2
        CODE=0
        OUTPUT=$(nix-shell --show-trace -E '${expr}' --run \
          'nix-shell --show-trace -E '"'"'${expr}'"'"' --run true' 2>&1) ||
          || fail "Nested shells failed: $OUTPUT"

        echo "$OUTPUT" 1>&2

        echo "Making sure we only checked git repos at most once" 1>&2
        SEEN=""
        while read -r LINE
        do
          URL=$(echo "$LINE" | sed -e 's/.*repo-head-//g' | grep -o '[a-z0-9]*')
          STAMP=$(echo "$LINE" | sed -e 's@.*store/@@g' | sed -e 's@-repo-head-.*@@g')
          ENTRY=$(echo -e "$URL\t$STAMP")
          while read -r STAMPS
          do
            FST=$(echo "$STAMPS" | cut -f2)
            SND=$(echo "$STAMPS" | cut -f3)
            [[ "x$FST" = "x$SND" ]] && fail "Multiple timestamps for '$URL'"
          done < <(join <(echo "$SEEN") <(echo "$ENTRY"))
          SEEN=$(echo "$SEEN"; echo "$ENTRY")
        done < <(echo "$OUTPUT" | grep "^building.*repo-head")

        echo "Looks OK" 1>&2
        echo "pass" > "$out"
      '';
}
