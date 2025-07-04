{ diffutils, jq, runCommand, runJq }:
with rec {
  # Use jq's default formatting, so equal JSON values become identical files
  normaliseJson = name: json: runCommand "normalised-${name}.json"
    {
      inherit json;
      buildInputs = [ jq ];
    }
    ''jq '.' < "$json" > "$out"'';

  # Various notions of equality/equivalence since each encoding can be formatted
  # in ways that don't affect the meaning.

  same = label: x: y: runCommand "${label}-are-same"
    {
      inherit x y;
      buildInputs = [ diffutils ];
    }
    ''cmp "$x" "$y" && mkdir "$out"'';

  sameJson = label: x: y:
    same label (normaliseJson "${label}-x" x) (normaliseJson "${label}-y" y);

  exampleJson = builtins.toJSON {
    foo = [ "fee" "fi" "fo" "fum" ];
    bar.baz = 42;
    quux = true;
    "" = null;
    hello = "world";
  };

  exampleYaml = ''
    foo:
     - fee
     - "fi"
     - fo
     - fum
    bar:
     baz: 42
    quux: True
    "": null
    hello: "world"
  '';

  exampleJsonFile =
    normaliseJson "example" (builtins.toFile "example.json" exampleJson);
};
{
  recurseForDerivations = true;

  json-identity = same "json-identity" exampleJsonFile (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
  });

  json-without-input = same "json-without-input" exampleJsonFile (runJq {
    inputFile = null;
    from = "json";
    to = "json";
    filter = exampleJson;
  });
}
