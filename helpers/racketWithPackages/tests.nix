{
  fetchFromGitHub,
  fetchgit,
  hasBinary,
  racketWithPackages,
}:

with {
  result = racketWithPackages [
    # Shell commands
    (fetchFromGitHub {
      owner = "willghatch";
      repo = "racket-shell-pipeline";
      rev = "5f4232b58552c0affee15612f93629c5d66db7ea";
      sha256 = "1kn3aflv7z44m65qj1jjjvvkh1d3sbwywscqd6y9gqpjkvfxwib3";
    })
  ];
};
{
  example-usage = result;
  example-has-racket = hasBinary result "racket";
}
