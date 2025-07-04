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

  # Helper to convert XML/TOML to JSON for comparison
  toJson = label: file: format: runJq {
    name = "to-json-${label}";
    inputFile = file;
    from = format;
    to = "json";
    filter = ".";
  };

  # Example files
  exampleJsonFile = ../example.json;
  exampleYamlFile = ../example.yaml;
  exampleXmlFile = ../example.xml;
  exampleTomlFile = ../example.toml;

  # Expected JSON representation of example files for comparison
  exampleJsonExpected = normaliseJson "example-json-expected" exampleJsonFile;
  exampleYamlExpected = toJson "example-yaml-expected" exampleYamlFile "yaml";
  exampleXmlExpected = toJson "example-xml-expected" exampleXmlFile "xml";
  exampleTomlExpected = toJson "example-toml-expected" exampleTomlFile "toml";

  # Expected output for specific filters
  exampleJsonFilteredExpected = builtins.toFile "example-json-filtered-expected.json" (builtins.toJSON "another string");
  exampleYamlFilteredExpected = builtins.toFile "example-yaml-filtered-expected.json" (builtins.toJSON "nested_value");
  exampleXmlFilteredExpected = builtins.toFile "example-xml-filtered-expected.json" (builtins.toJSON "This is some text content.");
  exampleTomlFilteredExpected = builtins.toFile "example-toml-filtered-expected.json" (builtins.toJSON "Tom Preston-Werner");

};
{
  recurseForDerivations = true;

  # JSON tests
  json-to-json-identity = sameJson "json-to-json-identity" exampleJsonExpected (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
  });

  json-to-yaml = same "json-to-yaml" exampleYamlFile (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "yaml";
    filter = ".";
  });

  json-to-xml = same "json-to-xml" exampleXmlFile (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "xml";
    filter = ".";
  });

  json-to-toml = same "json-to-toml" exampleTomlFile (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "toml";
    filter = ".";
  });

  json-filter-specific = sameJson "json-filter-specific" exampleJsonFilteredExpected (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".object_example.nested_string";
  });

  # YAML tests
  yaml-to-json = sameJson "yaml-to-json" exampleYamlExpected (runJq {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "json";
    filter = ".";
  });

  yaml-to-yaml-identity = same "yaml-to-yaml-identity" exampleYamlFile (runJq {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "yaml";
    filter = ".";
  });

  yaml-to-xml = same "yaml-to-xml" exampleXmlFile (runJq {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "xml";
    filter = ".";
  });

  yaml-to-toml = same "yaml-to-toml" exampleTomlFile (runJq {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "toml";
    filter = ".";
  });

  yaml-filter-specific = sameJson "yaml-filter-specific" exampleYamlFilteredExpected (runJq {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "json";
    filter = ".nested_map.level1.level2.key";
  });

  # XML tests (comparing JSON output for identity)
  xml-to-json = sameJson "xml-to-json" exampleXmlExpected (runJq {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".";
  });

  xml-to-xml-identity = sameJson "xml-to-xml-identity" exampleXmlExpected (toJson "xml-to-xml-output" (runJq {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "xml";
    filter = ".";
  }) "xml");

  xml-to-yaml = same "xml-to-yaml" exampleYamlFile (runJq {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "yaml";
    filter = ".";
  });

  xml-to-toml = same "xml-to-toml" exampleTomlFile (runJq {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "toml";
    filter = ".";
  });

  xml-filter-specific = sameJson "xml-filter-specific" exampleXmlFilteredExpected (runJq {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".root.element1.\"#text\""; # Note: xq/yq structure for text content
  });

  # TOML tests (comparing JSON output for identity)
  toml-to-json = sameJson "toml-to-json" exampleTomlExpected (runJq {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".";
  });

  toml-to-toml-identity = sameJson "toml-to-toml-identity" exampleTomlExpected (toJson "toml-to-toml-output" (runJq {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "toml";
    filter = ".";
  }) "toml");

  toml-to-yaml = same "toml-to-yaml" exampleYamlFile (runJq {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "yaml";
    filter = ".";
  });

  toml-to-xml = same "toml-to-xml" exampleXmlFile (runJq {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "xml";
    filter = ".";
  });

  toml-filter-specific = sameJson "toml-filter-specific" exampleTomlFilteredExpected (runJq {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".owner.name";
  });

  # Filter as list test
  json-filter-list = sameJson "json-filter-list" exampleJsonFilteredExpected (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = [ "." ".object_example" ".nested_string" ];
  });

  # Test with extraArgs
  json-extra-args = sameJson "json-extra-args" exampleJsonExpected (runJq {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
    extraArgs = [ "--compact-output" ]; # Example extra arg for jq
  });
}
