{
  bash,
  hackageIndex,
  jq,
  lib,
  writeScriptBin,
}:
writeScriptBin "curl" ''
  #!${bash}/bin/bash
  set -e
  set -o pipefail
  export PATH="${jq}/bin:$PATH"

  # Remember which file is being requested
  F=$(basename "$1")

  # Helper functions, to output the required file contents

  function sha { sha256sum - | cut -d' ' -f1; }
  function md5 {    md5sum - | cut -d' ' -f1; }

  function root {
    echo '${
      builtins.toJSON {
        signatures = [ ];
        signed = {
          _type = "Root";
          expires = "9999-01-01T00:00:00Z";
          keys = { };
          version = 5;
          roles =
            lib.genAttrs
              [
                "mirrors"
                "root"
                "snapshot"
                "targets"
                "timestamp"
              ]
              (_: {
                keyids = [ ];
                threshold = 0;
              });
        };
      }
    }'
  }

  function mirrors {
    echo '${
      builtins.toJSON {
        signatures = [ ];
        signed = {
          _type = "Mirrorlist";
          expires = "9999-01-01T00:00:00Z";
          mirrors = [ ];
          version = 1;
        };
      }
    }'
  }

  function snapshot {
    # This can take a few seconds, to hash the index twice
    echo '${
      builtins.toJSON {
        signatures = [ ];
        signed = {
          _type = "Snapshot";
          expires = "9999-01-01T00:00:00Z";
          version = 1;
          meta = {
            "<repo>/01-index.tar.gz".hashes = { };
            "<repo>/mirrors.json".hashes = { };
            "<repo>/root.json".hashes = { };
          };
        };
      }
    }' | jq --argjson rlen "$(root | wc -c                )" \
            --argjson mlen "$(mirrors | wc -c             )" \
            --argjson zlen "$(stat -c '%s' ${hackageIndex})" \
            --arg rmd5 "$(root    | md5        )" \
            --arg mmd5 "$(mirrors | md5        )" \
            --arg zmd5 "$(md5 < ${hackageIndex})" \
            --arg rsha "$(root    | sha        )" \
            --arg msha "$(mirrors | sha        )" \
            --arg zsha "$(sha < ${hackageIndex})" \
            '(.signed.meta["<repo>/root.json"      ] |= {
               "length": $rlen,
               "hashes": { "md5": $rmd5, "sha256": $rsha }
             }) |
             (.signed.meta["<repo>/mirrors.json"   ] |= {
               "length": $mlen,
               "hashes": { "md5": $mmd5, "sha256": $msha }
             }) |
             (.signed.meta["<repo>/01-index.tar.gz"] |= {
               "length": $zlen,
               "hashes": { "md5": $zmd5, "sha256": $zsha }
             })'
  }

  function timestamp {
    # Calculate snapshot.json once, to avoid re-hashing the index
    S=$(snapshot)
    echo '${
      builtins.toJSON {
        signatures = [ ];
        signed = {
          _type = "Timestamp";
          expires = "9999-01-01T00:00:00Z";
          meta."<repo>/snapshot.json".hashes = { };
          version = 1;
        };
      }
    }' | jq --argjson len "$(echo "$S" | wc -c)" \
            --arg     md5 "$(echo "$S" | md5  )" \
            --arg     sha "$(echo "$S" | sha  )" \
            '(.signed.meta["<repo>/snapshot.json"] |= {
               "length": $len,
               "hashes": { "md5": $md5, "sha256": $sha }
             })'
  }

  # Grab the output file paths requested by Cabal, and write empty headers
  while [[ "$#" -gt 0 ]]
  do
    echo "$@" 1>&2
    case "$1" in
      --output)
        OUTPUT="$2"
        shift 2
        ;;
      --dump-header)
        touch "$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Write the desired content to the output path Cabal is expecting
  case "$F" in
    *.json)
      case "$F" in
        *root.json) root;;
        *mirrors.json) mirrors;;
        *snapshot.json) snapshot;;
        *timestamp.json) timestamp;;
      esac > "$OUTPUT"
      ;;
    *index.tar.gz) cp ${hackageIndex} "$OUTPUT";;
    *)
      echo "UNKNOWN FILE REQUESTED '$F'" 1>&2
      exit 1
      ;;
  esac

  # Finish with a "success" HTTP code
  echo 200
''
