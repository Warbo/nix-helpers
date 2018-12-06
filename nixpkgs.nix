# Pinned nixpkgs repos
self: super:
with builtins // super.lib // {
  inherit (self) die;
};
with rec {
  getNixpkgs = { rev, sha256 }: super.fetchFromGitHub {
    inherit rev sha256;
    owner = "NixOS";
    repo  = "nixpkgs";
  };

  importPkgs = repo: import repo { config = {}; };

  repos = mapAttrs (_: getNixpkgs) repoData;

  repoData = {
    repo1603 = {
      rev    = "d231868";
      sha256 = "0m2b5ignccc5i5cyydhgcgbyl8bqip4dz32gw0c6761pd4kgw56v";
    };
    repo1609 = {
      rev    = "f22817d";
      sha256 = "1cx5cfsp4iiwq8921c15chn1mhjgzydvhdcmrvjmqzinxyz71bzh";
    };
    repo1703 = {
      rev    = "1849e69";
      sha256 = "1fw9ryrz1qzbaxnjqqf91yxk1pb9hgci0z0pzw53f675almmv9q2";
    };
    repo1709 = {
      rev    = "39cd40f";
      sha256 = "0kpx4h9p1lhjbn1gsil111swa62hmjs9g93xmsavfiki910s73sh";
    };
    repo1803 = {
      rev    = "94d80eb";
      sha256 = "1l4hdxwcqv5izxcgv3v4njq99yai8v38wx7v02v5sd96g7jj2i8f";
    };
    repo1809 = {
      rev    = "6a3f5bc";
      sha256 = "1ib96has10v5nr6bzf7v8kw7yzww8zanxgw2qi1ll1sbv6kj6zpd";
    };
  };

  loadRepo = n: v: {
    name  = replaceStrings [ "repo" ] [ "nixpkgs" ] n;
    value = import v ({ config = {}; } // (if compareVersions n "repo1703" == -1
                                             then {}
                                             else { overlays = []; }));
  };

  pkgSets = mapAttrs' loadRepo repos;
};

{
  defs  = repos // pkgSets // { inherit getNixpkgs; };
  tests = {
    # One reason to use old nixpkgs versions is for useful but obsolete KDE apps
    canAccessKde =
      with pkgSets;
      assert nixpkgs1603 ? kde4 || die {
        error = "nixpkgs1603 doesn't have 'kde4' attribute";
      };
      assert nixpkgs1603.callPackage ({ kde4 ? null }: kde4 != null) {} || die {
        error = "nixpkgs1603.callPackage should populate 'kde4' argument";
      };
      self.nothing;
  };
}
