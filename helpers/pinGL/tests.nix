{ backportOverlays, hasBinary, nixpkgs1609, nixpkgs1803, pinGL, repo1609,
  repo1803, runCommand }:

{
  intelFirefox1609 = hasBinary (pinGL {
    nixpkgsRepo = backportOverlays {
      name = "nixpkgs1609-for-firefox";
      repo = repo1609;
    };
    pkg         = nixpkgs1609.firefox;
    binaries    = [ "firefox" ];
    gl          = "Intel";
  }) "firefox";

  shebangsWillRun = runCommand "pinGL-shebangs-run"
    {
      wrapped = pinGL {
        binaries    = [ "hello" ];
        gl          = "Intel";
        nixpkgsRepo = repo1803;
        pkg         = nixpkgs1803.hello;
      };
    }
    ''
      "$wrapped"/bin/hello
      mkdir "$out"
    '';
}
