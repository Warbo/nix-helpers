# Runs a file through a given 'jq' filter. Also supports TOML, YAML and XML.
{
  catNull,
  fileExtension,
  jq,
  lib,
  mapNull,
  orElse,
  runCommand,
  sanitiseName,
  yq,
}:
with rec {
  inherit (builtins)
    baseNameOf
    concatLists
    getAttr
    hasAttr
    isList
    isString
    ;
  inherit (lib) concatMapStringsSep escapeShellArg removeSuffix toLower;

  # Normalises user-provided format to a smaller set
  formats = {
    json = "json";
    tml = "toml";
    toml = "toml";
    xml = "xml";
    yaml = "yaml";
    yml = "yaml";
  };

  # How to parse each input format. These also run the filter, and output JSON.
  inCommands = {
    json = "jq";
    toml = "tomlq";
    xml = "xq";
    yaml = "yq --yaml-roundtrip";
  };

  # How to convert the resulting JSON into each output format.
  outCommands = {
    json = "cat";

    # YAML is a superset of JSON, so thankfully yq can parse it
    toml = "yq --toml-output";
    yaml = "yq --yaml-output";
    xml = "yq --xml-output";
  };

  guessFormat =
    f:
    with {
      ext = toLower (orElse "json" (fileExtension f));
    };
    if hasAttr ext formats then getAttr ext formats else "json";

  pickName =
    {
      from,
      to,
      inputFile,
    }:
    with rec {
      ext = mapNull fileExtension inputFile;
      pretty = mapNull (ext: removeSuffix ".${ext}" (baseNameOf inputFile)) ext;
    };
    "runJq-on-${sanitiseName (orElse from pretty)}.${to}";

  # For convenience filters can also be given as a list (which we pipe-separate)
  # and can even be nested (which we wrap in parentheses).
  mkFilter =
    level:
    if isString level then
      "(" + level + ")"
    else if isList level then
      "(" + concatMapStringsSep " | " mkFilter level + ")"
    else
      abort ''
        filter should be string, or (nested) list of strings. Don't know what to
        do with '${toString level}'
      '';
};
{
  name ? pickName { inherit from to inputFile; },
  from ? orElse "json" (mapNull guessFormat inputFile),
  to ? "json",
  # If inputFile is given, it will be piped in; null will set the '-n' argument
  inputFile ? null,

  # The transformation to perform; see the 'jq' manual. If a list is given, we
  # will pipe-separate it (handy for long filters that span many lines); nesting
  # is also supported. Entries will be wrapped in parentheses.
  filter ? ".",

  # Arguments to give the input-processing command. Defaults to the given
  # filter, and possibly '-n' (if no 'inputFile' was given). If you only want to
  # prepend some extras, use 'extraArgs'.
  args ? concatLists [
    extraArgs
    (orElse [ "-n" ] (mapNull (_: [ ]) inputFile))
    [ (mkFilter filter) ]
  ],
  extraArgs ? [ ],
}:
with {
  argString = concatMapStringsSep " " escapeShellArg args;

  input = orElse "" (mapNull (f: "< ${inputFile}") inputFile);
};
runCommand name
  {
    buildInputs = [
      (
        {
          json = jq;
          toml = yq;
          xml = yq;
          yaml = yq;
        }
        .${from}
      )
    ];
  }
  ''
    ${inCommands.${from}} ${argString} ${input} | ${outCommands.${to}} > "$out"
  ''
