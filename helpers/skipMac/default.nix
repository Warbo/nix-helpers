{ stdenv }:

name: nonMac: if stdenv.isDarwin
                 then builtins.trace "Skipping ${name} on macOS" null
                 else nonMac
