{
  diffutils,
  jq,
  runCommand,
  runJq,
}:
with rec {
  # Use this to invoke runJq, so we can toggle debug on/off
  run = args: runJq ({ debug = true; } // args);

  # Use jq's default formatting, so equal JSON values become identical files
  normaliseJson =
    name: json:
    runCommand "normalised-${name}.json" {
      inherit json;
      buildInputs = [ jq ];
    } ''jq '.' < "$json" > "$out"'';

  # Various notions of equality/equivalence since each encoding can be formatted
  # in ways that don't affect the meaning.

  same =
    label: x: y:
    runCommand "${label}-are-same" {
      inherit x y;
      buildInputs = [ diffutils ];
    } ''cmp "$x" "$y" && mkdir "$out"'';

  sameJson =
    label: x: y:
    same label (normaliseJson "${label}-x" x) (normaliseJson "${label}-y" y);

  # Helper to convert XML/TOML to JSON for comparison
  toJson =
    label: file: format:
    run {
      name = "to-json-${label}";
      inputFile = file;
      from = format;
      to = "json";
      filter = ".";
    };

  # Example files
  exampleJsonFile = ./example.json;
  exampleYamlFile = ./example.yaml;
  exampleXmlFile = ./example.xml;
  exampleTomlFile = ./example.toml;

  # Expected JSON representation of example files for comparison
  exampleJsonExpected = normaliseJson "example-json-expected" exampleJsonFile;
  exampleYamlExpected = toJson "example-yaml-expected" exampleYamlFile "yaml";
  exampleXmlExpected = toJson "example-xml-expected" exampleXmlFile "xml";
  exampleTomlExpected = toJson "example-toml-expected" exampleTomlFile "toml";

  # Expected output for specific filters
  exampleJsonFilteredExpected = builtins.toFile "example-json-filtered-expected.json" (
    builtins.toJSON "another string"
  );
  exampleYamlFilteredExpected = builtins.toFile "example-yaml-filtered-expected.json" (
    builtins.toJSON "nested_value"
  );
  exampleXmlFilteredExpected = builtins.toFile "example-xml-filtered-expected.json" (
    builtins.toJSON "This is some text content."
  );
  exampleTomlFilteredExpected = builtins.toFile "example-toml-filtered-expected.json" (
    builtins.toJSON "Tom Preston-Werner"
  );

};
{
  recurseForDerivations = true;

  # JSON tests
  json-to-json-identity =
    sameJson "json-to-json-identity" exampleJsonExpected
      (run {
        inputFile = exampleJsonFile;
        from = "json";
        to = "json";
        filter = ".";
      });

  json-to-yaml = same "json-to-yaml" exampleYamlFile (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "yaml";
    filter = ".";
  });

  json-to-xml = same "json-to-xml" exampleXmlFile (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "xml";
    filter = ".";
  });

  json-to-toml = same "json-to-toml" exampleTomlFile (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "toml";
    filter = [
      "."
      "walk(if type == \"object\" then with_entries(select(.value != null)) else . end)"
    ];
  });

  json-filter-specific =
    sameJson "json-filter-specific" exampleJsonFilteredExpected
      (run {
        inputFile = exampleJsonFile;
        from = "json";
        to = "json";
        filter = ".object_example.nested_string";
      });

  # YAML tests
  yaml-to-json = sameJson "yaml-to-json" exampleYamlExpected (run {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "json";
    filter = ".";
  });

  yaml-to-yaml-identity = same "yaml-to-yaml-identity" exampleYamlFile (run {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "yaml";
    filter = ".";
  });

  yaml-to-xml = same "yaml-to-xml" exampleXmlFile (run {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "xml";
    filter = ".";
  });

  yaml-to-toml = same "yaml-to-toml" exampleTomlFile (run {
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "toml";
    filter = [
      ".[0]"
      "walk(if type == \"object\" then with_entries(select(.value != null)) else . end)"
    ];
  });

  yaml-filter-specific =
    sameJson "yaml-filter-specific" exampleYamlFilteredExpected
      (run {
        inputFile = exampleYamlFile;
        from = "yaml";
        to = "json";
        filter = ".nested_map.level1.level2.key";
      });

  # XML tests (comparing JSON output for identity)
  xml-to-json = sameJson "xml-to-json" exampleXmlExpected (run {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".";
  });

  xml-to-xml-identity = sameJson "xml-to-xml-identity" exampleXmlExpected (
    toJson "xml-to-xml-output" (run {
      inputFile = exampleXmlFile;
      from = "xml";
      to = "xml";
      filter = ".";
    }) "xml"
  );

  xml-to-yaml = same "xml-to-yaml" exampleYamlFile (run {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "yaml";
    filter = ".";
  });

  xml-to-toml = same "xml-to-toml" exampleTomlFile (run {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "toml";
    filter = [
      "."
      "walk(if type == \"object\" then with_entries(select(.value != null)) else . end)"
    ];
  });

  xml-filter-specific =
    sameJson "xml-filter-specific" exampleXmlFilteredExpected
      (run {
        inputFile = exampleXmlFile;
        from = "xml";
        to = "json";
        filter = ".root.element1.\"#text\""; # Note: xq/yq structure for text content
      });

  # TOML tests (comparing JSON output for identity)
  toml-to-json = sameJson "toml-to-json" exampleTomlExpected (run {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".";
  });

  toml-to-toml-identity = sameJson "toml-to-toml-identity" exampleTomlExpected (
    toJson "toml-to-toml-output" (run {
      inputFile = exampleTomlFile;
      from = "toml";
      to = "toml";
      filter = ".";
    }) "toml"
  );

  toml-to-yaml = same "toml-to-yaml" exampleYamlFile (run {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "yaml";
    filter = ".";
  });

  toml-to-xml = same "toml-to-xml" exampleXmlFile (run {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "xml";
    filter = ".";
  });

  toml-filter-specific =
    sameJson "toml-filter-specific" exampleTomlFilteredExpected
      (run {
        inputFile = exampleTomlFile;
        from = "toml";
        to = "json";
        filter = ".owner.name";
      });

  # Filter as list test
  json-filter-list =
    sameJson "json-filter-list" exampleJsonFilteredExpected
      (run {
        inputFile = exampleJsonFile;
        from = "json";
        to = "json";
        filter = [
          "."
          ".object_example"
          ".nested_string"
        ];
      });

  # Test with extraArgs
  json-extra-args = sameJson "json-extra-args" exampleJsonExpected (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
    extraArgs = [ "--compact-output" ]; # Example extra arg for jq
  });
}
