{
  bash,
  ghc,
  python3,
  racket,
  run,
}:

{
  run-bash = run {
    name = "run-bash-test";
    paths = [ bash ];
    script = ''
      #!${bash}/bin/bash
      mkdir "$out"
    '';
  };

  run-haskell = run {
    name = "run-haskell-test";
    paths = [ ghc ];
    script = ''
      #!${ghc}/bin/runhaskell
      import System.Directory
      import System.Environment
      main = getEnv "out" >>= createDirectory
    '';
  };

  run-python = run {
    name = "run-python-test";
    paths = [ python3 ];
    script = ''
      #!${python3}/bin/python
      import os
      os.mkdir(os.getenv('out'))
    '';
  };

  run-racket = run {
    name = "run-racket-test";
    paths = [ racket ];
    script = ''
      #!${racket}/bin/racket
      #lang racket
      (make-directory* (getenv "out"))
    '';
  };
}
