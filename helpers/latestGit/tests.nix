{ dummyBuild, isDerivation, latestGit }:

with builtins;
with rec {
  url = "http://example.org";

  repos = {
    stable = latestGit {
      inherit url;
      stable = { rev = "123"; sha256 = "abc"; unsafeSkip = false; };
    };

    unstable = latestGit {
      inherit url;
      stable = { unsafeSkip = true; };
    };

    deep = latestGit {
      inherit url;
      stable    = { rev = "123"; sha256 = "abc"; unsafeSkip = false; };
      deepClone = true;
    };
  };

  isDrv = name: isDerivation (getAttr name repos) || die {
    inherit name;
    error = "Test repo should give a derivation";
    type  = typeOf (getAttr name repos);
  };

  checks = all isDrv (attrNames repos);
};
{
  checks = assert checks; dummyBuild "latestGit-checks";
}
