{ bash, ghc, nixpkgs1609, python, runCommand, wrap }:

rec {
  def = args: runCommand args.name {} (wrap (args // {
    name = "${args.name}-runner";
  }));

  tests = {
    run-bash = def {
      name   = "run-bash-test";
      paths  = [ bash ];
      script = ''
        #!${bash}/bin/bash
        mkdir "$out"
      '';
    };

    run-haskell = def {
      name   = "run-haskell-test";
      paths  = [ ghc ];
      script = ''
        #!${ghc}/bin/runhaskell
        import System.Directory
        import System.Environment
        main = getEnv "out" >>= createDirectory
      '';
    };

    run-python = def {
      name   = "run-python-test";
      paths  = [ python ];
      script = ''
        #!${python}/bin/python
        import os
        os.mkdir(os.getenv('out'))
      '';
    };

    run-racket = def {
      name  = "run-racket-test";
      paths = [ nixpkgs1609.racket ];
      script = ''
        #!${nixpkgs1609.racket}/bin/racket
        #lang racket
        (make-directory* (getenv "out"))
      '';
    };
  };
}
