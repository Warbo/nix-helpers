{ lib, nix, runCommand, writeScript }:
with builtins; with lib;

env: text:

# Allows us to call Nix commands from our scripts
let nixEnv = env // {
               NIX_REMOTE  = "daemon";
               NIX_PATH    = builtins.getEnv "NIX_PATH";
               buildInputs = [ nix ] ++ (if env ? buildInputs
                                            then env.buildInputs
                                            else []);
             };
    script = writeScript "script" text;
    runner = runCommand  "runner" nixEnv script;
 in readFile "${runner}"
