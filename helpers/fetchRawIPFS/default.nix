_:
{ sha256 }:
with rec {
  inherit (builtins) convertHash getEnv;
  cid = "f01551220${
    convertHash {
      hash = sha256;
      hashAlgo = "sha256";
      toHashFormat = "base16";
    }
  }";

  # fetchurl only takes one URL, so allow it to be overridden by env var.
  override = getEnv "IPFS_GATEWAY";
  gateway = if override == "" then "https://ipfs.io" else override;
};
import <nix/fetchurl.nix> {
  hash = convertHash {
    hash = sha256;
    hashAlgo = "sha256";
    toHashFormat = "sri";
  };
  url = "${gateway}/ipfs/${cid}";
}
