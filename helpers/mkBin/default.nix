# Shorthand for making a script via 'wrap' and installing it to a bin/ directory
{
  attrsToDirs',
  sanitiseName,
  wrap,
}:

with rec {
  go =
    args:
    attrsToDirs' (sanitiseName args.name) {
      bin = builtins.listToAttrs [
        {
          inherit (args) name;
          value = wrap args;
        }
      ];
    };
};
go
