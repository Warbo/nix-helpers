{
  runCommand,
  wrap,
}:

args:
with {
  # Allow derivation arguments to be given/overridden
  drvArgs = args.drvExtras or { };

  # Arguments for the command we're running. By default we remove fooExtras
  # and invent a name; this can be overridden by setting 'cmdExtras'.
  cmdArgs =
    builtins.removeAttrs args [
      "cmdExtras"
      "drvExtras"
    ]
    // {
      name = "${args.name}-runner";
    }
    // (args.cmdExtras or { });
};
runCommand args.name drvArgs (wrap cmdArgs)
