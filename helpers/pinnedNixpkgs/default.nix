# Pinned nixpkgs repos
{
  nixpkgs-lib ? import ../nixpkgs-lib { },
  getNixpkgs ? import ../getNixpkgs {}
}:
with rec {
  inherit (builtins)
    abort
    attrNames
    compareVersions
    getAttr
    mapAttrs
    ;
  inherit (nixpkgs-lib)
    filterAttrs
    foldl'
    hasPrefix
    mapAttrs'
    replaceStrings
    stringLength
    ;

  repos = mapAttrs (_: getNixpkgs) {
    repo1603 = {
      rev = "d231868990f8b2d471648d76f07e747f396b9421";
      sha256 = "0m2b5ignccc5i5cyydhgcgbyl8bqip4dz32gw0c6761pd4kgw56v";
    };
    repo1609 = {
      rev = "f22817d8d2bc17d2bcdb8ac4308a4bce6f5d1d2b";
      sha256 = "1cx5cfsp4iiwq8921c15chn1mhjgzydvhdcmrvjmqzinxyz71bzh";
    };
    repo1703 = {
      rev = "1849e695b00a54cda86cb75202240d949c10c7ce";
      sha256 = "1fw9ryrz1qzbaxnjqqf91yxk1pb9hgci0z0pzw53f675almmv9q2";
    };
    repo1709 = {
      rev = "39cd40f7bea40116ecb756d46a687bfd0d2e550e";
      sha256 = "0kpx4h9p1lhjbn1gsil111swa62hmjs9g93xmsavfiki910s73sh";
    };
    repo1803 = {
      rev = "94d80eb72474bf8243b841058ce45eac2b163943";
      sha256 = "1l4hdxwcqv5izxcgv3v4njq99yai8v38wx7v02v5sd96g7jj2i8f";
    };
    repo1809 = {
      rev = "94d80eb72474bf8243b841058ce45eac2b163943";
      sha256 = "1l4hdxwcqv5izxcgv3v4njq99yai8v38wx7v02v5sd96g7jj2i8f";
    };
    repo1903 = {
      rev = "f52505fac8c82716872a616c501ad9eff188f97f";
      sha256 = "0q2m2qhyga9yq29yz90ywgjbn9hdahs7i8wwlq7b55rdbyiwa5dy";
    };
    repo1909 = {
      rev = "d5291756487d70bc336e33512a9baf9fa1788faf";
      sha256 = "0mhqhq21y5vrr1f30qd2bvydv4bbbslvyzclhw0kdxmkgg3z4c92";
    };
    repo2003 = {
      rev = "6ec10fc77e56b9f848930f129833cfbbac736e4f";
      sha256 = "196nhr6dcwc2v6aansw74vaqznpq3p4qfrlqv12lplnzwyfhyxxc";
    };
    repo2009 = {
      rev = "f2b81a021eccc072029f8a93b45b2c9a9ce0aa2a";
      sha256 = "06hgvyd8ry4i49dmjxh5n6wv1j5ifpp7i3a7bjz62san0q6d0j35";
    };
    repo2105 = {
      rev = "2d6ab6c6b92f7aaf8bc53baba9754b9bfdce56f2";
      sha256 = "1aafqly1mcqxh0r15mrlsrs4znldhm7cizsmfp3d25lqssay6gjd";
    };
    repo2111 = {
      rev = "521e4d7d13b09bc0a21976b9d19abd197d4e3b1e";
      sha256 = "156b4wnm6y6lg0gz09mp48rd0mhcdazr5s888c4lbhlpn3j8h042";
    };
    repo2205 = {
      rev = "71d7a4c037dc4f3e98d5c4a81b941933cf5bf675";
      sha256 = "0mz1mrygnpwv87dd0sac32q3m8902ppn9zrkn4wrryljwvvpf60s";
    };
    repo2211 = {
      rev = "628d4bb6e9f4f0c30cfd9b23d3c1cdcec9d3cb5c";
      sha256 = "1vazd3ingc6vffhynhk8q9misrnvlgmh682kmm09x2bmdzd3l4ad";
    };
    repo2305 = {
      rev = "4ecab3273592f27479a583fb6d975d4aba3486fe";
      sha256 = "10wn0l08j9lgqcw8177nh2ljrnxdrpri7bp0g7nvrsn9rkawvlbf";
    };
    repo2311 = {
      rev = "057f9aecfb71c4437d2b27d3323df7f93c010b7e";
      sha256 = "1ndiv385w1qyb3b18vw13991fzb9wg4cl21wglk89grsfsnra41k";
    };
    repo2405 = {
      rev = "47b604b07d1e8146d5398b42d3306fdebd343986";
      sha256 = "0g0nl5dprv52zq33wphjydbf3xy0kajp0yix7xg2m0qgp83pp046";
    };
    repo2411 = {
      rev = "62c435d93bf046a5396f3016472e8f7c8e2aed65";
      sha256 = "0zpvadqbs19jblnd0j2rfs9m7j0n5spx0vilq8907g2gqrx63fqp";
    };
    repo2505 = {
      # As long as fetchTreeFromGitHub relies on nixpkgsLatest.fetchurl, the
      # latest entry needs to use a rev & sha256, rather than a tree
      rev = "11cb3517b3af6af300dd6c055aeda73c9bf52c48";
      sha256 = "1915r28xc4znrh2vf4rrjnxldw2imysz819gzhk9qlrkqanmfsxd";
    };
  };

  pkgSets = mapAttrs' (n: v: {
    name = replaceStrings [ "repo" ] [ "nixpkgs" ] n;
    value = import v (
      {
        config = { };
      }
      // (if compareVersions n "repo1703" == -1 then { } else { overlays = [ ]; })
    );
  }) repos;

  latest =
    attrs:
    with {
      attr = foldl' (
        found: name:
        if found == null || compareVersions name found == 1 then name else found
      ) null (attrNames attrs);
    };
    assert attr != null || abort "Can't get latest from empty set";
    getAttr attr attrs;
};

repos
// pkgSets
// {
  repoLatest = latest repos;
  nixpkgsLatest = latest pkgSets;
}
