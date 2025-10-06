{
  fetchFromGitHub,
  fetchgit,
  hasBinary,
  racketWithPackages,
  runCommand,
  writeScript,
}:

with {
  result = racketWithPackages [
    # Shell commands
    (fetchFromGitHub {
      owner = "willghatch";
      repo = "racket-shell-pipeline";
      rev = "a3a49248cca038e21ca489d757c4794737310ce7";
      sha256 = "sha256:0x1fhgzkj4xr7q5yplqbngk6cdwg85kmnc28hfmmsxvn8vismqsm";
    })
  ];
};
{
  example-usage = result;
  example-has-racket = hasBinary result "racket";
  example-can-load-package =
    runCommand "test-racketWithPackages-can-load-package" { }
      "${writeScript "test-racketWithPackages-can-load-package.rkt" ''
        #!${result}/bin/racket
        #lang racket
        (require shell/pipeline)
        (define content "success")
        (define out (getenv "out"))
        (run-pipeline/out
          `(echo ,content)
          `(tee ,out))
      ''}";
}
