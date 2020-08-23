{ fetchFromGitHub }:

{
  def = { rev, sha256 }: fetchFromGitHub {
    inherit rev sha256;
    owner = "NixOS";
    repo  = "nixpkgs";
  };

  tests = {};
}
