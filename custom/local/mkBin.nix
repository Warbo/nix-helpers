# Shorthand for making a script via 'wrap' and installing it to a bin/ directory
{ attrsToDirs, wrap }:

args: attrsToDirs {
  bin = builtins.listToAttrs [{
    inherit (args) name;
    value = wrap args;
  }];
}
