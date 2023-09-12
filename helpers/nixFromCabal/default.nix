{ die }:

src_: f:
die {
  inherit src_;
  error = "deprecated";
  function = "nixFromCabal";
  message = ''
    nixFromCabal is overly complex, does too much and can be replaced with
    other functions. In particular:
      - nixpkgs functions like hackage2nix and haskellSrc2nix can make a Nix
        function from a Cabal project.
      - Running a function whilst preserving names can be achieved using the
        withArgs, withArgsOf or composeWithArgs functions.
  '';
}
