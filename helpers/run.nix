{ bash, ghc, python, racket, runCommand, wrap }:

rec {
  def = args: runCommand args.name {} (wrap (args // {
    name = "${args.name}-runner";
  }));

  tests = {
    run-bash = def {
      name   = "run-bash-test";
      paths  = [ bash ];
      script = ''
        #!/usr/bin/env bash
        mkdir "$out"
      '';
    };

    run-haskell = def {
      name   = "run-haskell-test";
      paths  = [ ghc ];
      script = ''
        #!/usr/bin/env runhaskell
        import System.Directory
        import System.Environment
        main = getEnv "out" >>= createDirectory
      '';
    };

    run-python = def {
      name   = "run-python-test";
      paths  = [ python ];
      script = ''
        #!/usr/bin/env python
        import os
        os.mkdir(os.getenv('out'))
      '';
    };

    run-racket = def {
      name  = "run-racket-test";
      paths = [ racket ];
      script = ''
        #!/usr/bin/env racket
        #lang racket
        (make-directory* (getenv "out"))
      '';
    };
  };
}
