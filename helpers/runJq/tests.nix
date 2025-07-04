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
    sameJson "json-to-json-identity" (normaliseJson "example-json-expected" exampleJsonFile)
      (run {
        inputFile = exampleJsonFile;
        from = "json";
        to = "json";
        filter = ".";
      });

  json-to-yaml = run {
    name = "json-to-yaml";
    inputFile = exampleJsonFile;
    from = "json";
    to = "yaml";
    filter = ".string_example and .integer_example and (.array_example | is_array) and (.object_example | is_object) // halt_error(\"JSON to YAML conversion failed\")";
  };

  json-to-xml = run {
    name = "json-to-xml";
    inputFile = exampleJsonFile;
    from = "json";
    to = "xml";
    filter = ".root.string_example and .root.integer_example and (.root.array_example | is_array) and (.root.object_example | is_object) // halt_error(\"JSON to XML conversion failed\")";
  };

  json-to-toml = run {
    name = "json-to-toml";
    inputFile = exampleJsonFile;
    from = "json";
    to = "toml";
    filter = ".string and .integer and .float and (.boolean_true | is_boolean) and (.boolean_false | is_boolean) and (.simple_array | is_array) and .owner.name and .database.server // halt_error(\"JSON to TOML conversion failed\")";
  };

  json-filter-specific =
    sameJson "json-filter-specific" exampleJsonFilteredExpected
      (run {
        inputFile = exampleJsonFile;
        from = "json";
        to = "json";
        filter = ".object_example.nested_string";
      });

  # YAML tests
  yaml-to-json = sameJson "yaml-to-json" (normaliseJson "example-yaml-expected" (run {
    name = "yaml-to-json-intermediate";
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "json";
    filter = ".";
  })) (run {
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

  yaml-to-xml = run {
    name = "yaml-to-xml";
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "xml";
    filter = ".root.string_key and .root.integer_key and (.root.list_of_strings | is_array) and (.root.nested_map | is_object) // halt_error(\"YAML to XML conversion failed\")";
  };

  yaml-to-toml = run {
    name = "yaml-to-toml";
    inputFile = exampleYamlFile;
    from = "yaml";
    to = "toml";
    filter = ".string_key and .integer_key and .float_key and (.boolean_true | is_boolean) and (.boolean_false | is_boolean) and (.list_of_numbers | is_array) and .nested_map.level1.level2.key // halt_error(\"YAML to TOML conversion failed\")";
  };

  yaml-filter-specific =
    sameJson "yaml-filter-specific" exampleYamlFilteredExpected
      (run {
        inputFile = exampleYamlFile;
        from = "yaml";
        to = "json";
        filter = ".nested_map.level1.level2.key";
      });

  # XML tests (comparing JSON output for identity)
  xml-to-json = sameJson "xml-to-json" (normaliseJson "example-xml-expected" (run {
    name = "xml-to-json-intermediate";
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".";
  })) (run {
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".";
  });

  xml-to-xml-identity = sameJson "xml-to-xml-identity" (normaliseJson "xml-to-xml-output-json" (run {
      inputFile = exampleXmlFile;
      from = "xml";
      to = "xml";
      filter = ".";
    })) (normaliseJson "example-xml-expected" (run {
    name = "xml-to-json-intermediate-for-identity";
    inputFile = exampleXmlFile;
    from = "xml";
    to = "json";
    filter = ".";
  }));

  xml-to-yaml = run {
    name = "xml-to-yaml";
    inputFile = exampleXmlFile;
    from = "xml";
    to = "yaml";
    filter = ".root.element1.\"#text\" and .root.element2.\"test:namespacedElement\".\"#text\" and .root.element3.\"#text\" // halt_error(\"XML to YAML conversion failed\")";
  };

  xml-to-toml = run {
    name = "xml-to-toml";
    inputFile = exampleXmlFile;
    from = "xml";
    to = "toml";
    filter = ".root.element1.\"#text\" and .root.element1.\"@attribute1\" and .root.element2.\"test:namespacedElement\".\"#text\" // halt_error(\"XML to TOML conversion failed\")";
  };

  xml-filter-specific =
    sameJson "xml-filter-specific" exampleXmlFilteredExpected
      (run {
        inputFile = exampleXmlFile;
        from = "xml";
        to = "json";
        filter = ".root.element1.\"#text\""; # Note: xq/yq structure for text content
      });

  # TOML tests (comparing JSON output for identity)
  toml-to-json = sameJson "toml-to-json" (normaliseJson "example-toml-expected" (run {
    name = "toml-to-json-intermediate";
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".";
  })) (run {
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".";
  });

  toml-to-toml-identity = sameJson "toml-to-toml-identity" (normaliseJson "toml-to-toml-output-json" (run {
      inputFile = exampleTomlFile;
      from = "toml";
      to = "toml";
      filter = ".";
    })) (normaliseJson "example-toml-expected" (run {
    name = "toml-to-json-intermediate-for-identity";
    inputFile = exampleTomlFile;
    from = "toml";
    to = "json";
    filter = ".";
  }));

  toml-to-yaml = run {
    name = "toml-to-yaml";
    inputFile = exampleTomlFile;
    from = "toml";
    to = "yaml";
    filter = ".string and .integer and .float and (.boolean_true | is_boolean) and (.boolean_false | is_boolean) and (.simple_array | is_array) and .owner.name and .database.server // halt_error(\"TOML to YAML conversion failed\")";
  };

  toml-to-xml = run {
    name = "toml-to-xml";
    inputFile = exampleTomlFile;
    from = "toml";
    to = "xml";
    filter = ".root.string and .root.integer and .root.float and (.root.boolean_true | is_boolean) and (.root.boolean_false | is_boolean) and (.root.simple_array | is_array) and .root.owner.name and .root.database.server // halt_error(\"TOML to XML conversion failed\")";
  };

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
  json-extra-args = sameJson "json-extra-args" (normaliseJson "example-json-expected" exampleJsonFile) (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
    extraArgs = [ "--compact-output" ]; # Example extra arg for jq
  });
}
