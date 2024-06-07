{
  checkedRacket,
  fetchFromGitHub,
  fetchgit,
  hasBinary,
  racketWithPackages,
}:

with {
  result = racketWithPackages.override { racket = checkedRacket; } [
    # Dependency of grommet
    (fetchgit {
      url = "https://gitlab.com/RayRacine/grip.git";
      rev = "ec498f6";
      sha256 = "06ax30r70sz2hq0dzyassczcdkpmcd4p62zx0jwgc2zp3v0wl89l";
    })

    # Hashing
    (fetchgit {
      url = "https://gitlab.com/RayRacine/grommet.git";
      rev = "50f1b6a";
      sha256 = "1rb7i8jx7gg2rm5flnql0hja4ph11p7i38ryxd04yqw50l0xj59v";
    })

    # Shell commands
    (fetchFromGitHub {
      owner = "willghatch";
      repo = "racket-shell-pipeline";
      rev = "7ed9a75";
      sha256 = "06z5bhmvpdhy4bakh30fzha4s0xp2arjq8h9cyi65b1y18cd148x";
    })
  ];
};
{
  example-usage = result;
  example-has-racket = hasBinary result "racket";
}
