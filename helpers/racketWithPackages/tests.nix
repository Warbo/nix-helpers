{
  applyPatches,
  fetchFromGitHub,
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
    # Property checker
    (applyPatches {
      name = "rackcheck-with-main";
      src = fetchGit {
        name = "rackcheck-src";
        url = "https://github.com/Bogdanp/rackcheck.git";
        ref = "master";
        rev = "21dcda3edf86c28d9594887e92c5d7bef589897c";
      };
      postPatch = ''
        rm -r examples
        rm -r rackcheck
      '';
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
  example-can-test-submodule =
    runCommand "test-racketWithPackages-can-test-submodule"
      {
        buildInputs = [ result ];
        script = writeScript "racketWithPackages-test.rkt" ''
          #lang racket
          (module+ test
            (require rackunit rackcheck-lib))

          (define foo 123)
          (module+ test
            (check-property (property testy ([n gen:natural])
                              (check-equal? (+ foo n) (+ n foo) "+ commutes"))))
        '';
      }
      ''
        raco test "$script" && echo done > "$out"
      '';
}
