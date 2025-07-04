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

  # JSON to other formats (check conversion by converting back to JSON)
  json-to-yaml = run {
    name = "json-to-yaml-check";
    inputFile = run {
      name = "json-to-yaml-output";
      inputFile = exampleJsonFile;
      from = "json";
      to = "yaml";
      filter = ".";
    };
    from = "yaml";
    to = "json";
    # Check for presence of key elements from the original JSON
    filter = [
      ". as $x"
      "$x.string_example | if . then . else halt_error(\"JSON to YAML conversion failed: missing string_example\") end"
      "$x.integer_example | if . then . else halt_error(\"JSON to YAML conversion failed: missing integer_example\") end"
      "$x.array_example | if (is_array) then . else halt_error(\"JSON to YAML conversion failed: array_example is not an array\") end"
      "$x.object_example | if (is_object) then . else halt_error(\"JSON to YAML conversion failed: object_example is not an object\") end"
    ];
  };

  json-to-xml = run {
    name = "json-to-xml-check";
    inputFile = run {
      name = "json-to-xml-output";
      inputFile = exampleJsonFile;
      from = "json";
      to = "xml";
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ". as $x"
      "$x.root.string_example.\"#text\" | if . then . else halt_error(\"JSON to XML conversion failed: missing root.string_example.#text\") end"
      "$x.root.integer_example.\"#text\" | if . then . else halt_error(\"JSON to XML conversion failed: missing root.integer_example.#text\") end"
      "$x.root.array_example | if (is_array) then . else halt_error(\"JSON to XML conversion failed: root.array_example is not an array\") end"
      "$x.root.object_example | if (is_object) then . else halt_error(\"JSON to XML conversion failed: root.object_example is not an object\") end"
    ];
  };

  json-to-toml = run {
    name = "json-to-toml-check";
    inputFile = run {
      name = "json-to-toml-output";
      inputFile = exampleJsonFile;
      from = "json";
      to = "toml";
      filter = ".";
    };
    from = "toml";
    to = "json";
    # Check for presence of simple types that TOML can represent
    filter = [
      ". as $x"
      "$x.string_example | if . then . else halt_error(\"JSON to TOML conversion failed: missing string_example\") end"
      "$x.integer_example | if . then . else halt_error(\"JSON to TOML conversion failed: missing integer_example\") end"
      "$x.float_example | if . then . else halt_error(\"JSON to TOML conversion failed: missing float_example\") end"
      "$x.boolean_true | if (is_boolean) then . else halt_error(\"JSON to TOML conversion failed: boolean_true is not a boolean\") end"
      "$x.boolean_false | if (is_boolean) then . else halt_error(\"JSON to TOML conversion failed: boolean_false is not a boolean\") end"
    ];
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

  # YAML to other formats (check conversion by converting back to JSON)
  yaml-to-xml = run {
    name = "yaml-to-xml-check";
    inputFile = run {
      name = "yaml-to-xml-output";
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "xml";
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ". as $x"
      "$x.root.string_key.\"#text\" | if . then . else halt_error(\"YAML to XML conversion failed: missing root.string_key.#text\") end"
      "$x.root.integer_key.\"#text\" | if . then . else halt_error(\"YAML to XML conversion failed: missing root.integer_key.#text\") end"
      "$x.root.list_of_strings | if (is_array) then . else halt_error(\"YAML to XML conversion failed: root.list_of_strings is not an array\") end"
      "$x.root.nested_map | if (is_object) then . else halt_error(\"YAML to XML conversion failed: root.nested_map is not an object\") end"
    ];
  };

  yaml-to-toml = run {
    name = "yaml-to-toml-check";
    inputFile = run {
      name = "yaml-to-toml-output";
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "toml";
      filter = ".";
    };
    from = "toml";
    to = "json";
    # Check for presence of key elements that TOML can represent
    filter = [
      ". as $x"
      "$x.string_key | if . then . else halt_error(\"YAML to TOML conversion failed: missing string_key\") end"
      "$x.integer_key | if . then . else halt_error(\"YAML to TOML conversion failed: missing integer_key\") end"
      "$x.float_key | if . then . else halt_error(\"YAML to TOML conversion failed: missing float_key\") end"
      "$x.boolean_true | if (is_boolean) then . else halt_error(\"YAML to TOML conversion failed: boolean_true is not a boolean\") end"
      "$x.boolean_false | if (is_boolean) then . else halt_error(\"YAML to TOML conversion failed: boolean_false is not a boolean\") end"
      "$x.list_of_numbers | if (is_array) then . else halt_error(\"YAML to TOML conversion failed: list_of_numbers is not an array\") end"
      "$x.nested_map.level1.level2.key | if . then . else halt_error(\"YAML to TOML conversion failed: missing nested_map.level1.level2.key\") end"
    ];
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

  # XML to other formats (check conversion by converting back to JSON)
  xml-to-yaml = run {
    name = "xml-to-yaml-check";
    inputFile = run {
      name = "xml-to-yaml-output";
      inputFile = exampleXmlFile;
      from = "xml";
      to = "yaml";
      filter = ".";
    };
    from = "yaml";
    to = "json";
    # Check for presence of key elements from the XML-to-JSON structure
    filter = [
      ". as $x"
      "$x.root.element1.\"#text\" | if . then . else halt_error(\"XML to YAML conversion failed: missing root.element1.#text\") end"
      "$x.root.element1.\"@attribute1\" | if . then . else halt_error(\"XML to YAML conversion failed: missing root.element1.@attribute1\") end"
      "$x.root.element2.\"test:namespacedElement\".\"#text\" | if . then . else halt_error(\"XML to YAML conversion failed: missing root.element2.test:namespacedElement.#text\") end"
      "$x.root.element3.\"#text\" | if . then . else halt_error(\"XML to YAML conversion failed: missing root.element3.#text\") end"
    ];
  };

  xml-to-toml = run {
    name = "xml-to-toml-check";
    inputFile = run {
      name = "xml-to-toml-output";
      inputFile = exampleXmlFile;
      from = "xml";
      to = "toml";
      filter = ".";
    };
    from = "toml";
    to = "json";
    # Check for presence of key elements that TOML can represent
    filter = [
      ". as $x"
      "$x.root.element1.\"#text\" | if . then . else halt_error(\"XML to TOML conversion failed: missing root.element1.#text\") end"
      "$x.root.element1.\"@attribute1\" | if . then . else halt_error(\"XML to TOML conversion failed: missing root.element1.@attribute1\") end"
      "$x.root.element2.\"test:namespacedElement\".\"#text\" | if . then . else halt_error(\"XML to TOML conversion failed: missing root.element2.test:namespacedElement.#text\") end"
    ];
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

  # TOML to other formats (check conversion by converting back to JSON)
  toml-to-yaml = run {
    name = "toml-to-yaml-check";
    inputFile = run {
      name = "toml-to-yaml-output";
      inputFile = exampleTomlFile;
      from = "toml";
      to = "yaml";
      filter = ".";
    };
    from = "yaml";
    to = "json";
    # Check for presence of key elements from the original TOML
    filter = [
      ". as $x"
      "$x.string | if . then . else halt_error(\"TOML to YAML conversion failed: missing string\") end"
      "$x.integer | if . then . else halt_error(\"TOML to YAML conversion failed: missing integer\") end"
      "$x.float | if . then . else halt_error(\"TOML to YAML conversion failed: missing float\") end"
      "$x.boolean_true | if (is_boolean) then . else halt_error(\"TOML to YAML conversion failed: boolean_true is not a boolean\") end"
      "$x.boolean_false | if (is_boolean) then . else halt_error(\"TOML to YAML conversion failed: boolean_false is not a boolean\") end"
      "$x.simple_array | if (is_array) then . else halt_error(\"TOML to YAML conversion failed: simple_array is not an array\") end"
      "$x.owner.name | if . then . else halt_error(\"TOML to YAML conversion failed: missing owner.name\") end"
      "$x.database.server | if . then . else halt_error(\"TOML to YAML conversion failed: missing database.server\") end"
    ];
  };

  toml-to-xml = run {
    name = "toml-to-xml-check";
    inputFile = run {
      name = "toml-to-xml-output";
      inputFile = exampleTomlFile;
      from = "toml";
      to = "xml";
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ". as $x"
      "$x.root.string.\"#text\" | if . then . else halt_error(\"TOML to XML conversion failed: missing root.string.#text\") end"
      "$x.root.integer.\"#text\" | if . then . else halt_error(\"TOML to XML conversion failed: missing root.integer.#text\") end"
      "$x.root.float.\"#text\" | if . then . else halt_error(\"TOML to XML conversion failed: missing root.float.#text\") end"
      "$x.root.boolean_true | if (is_boolean) then . else halt_error(\"TOML to XML conversion failed: root.boolean_true is not a boolean\") end"
      "$x.root.boolean_false | if (is_boolean) then . else halt_error(\"TOML to XML conversion failed: root.boolean_false is not a boolean\") end"
      "$x.root.simple_array | if (is_array) then . else halt_error(\"TOML to XML conversion failed: root.simple_array is not an array\") end"
      "$x.root.owner.name.\"#text\" | if . then . else halt_error(\"TOML to XML conversion failed: missing root.owner.name.#text\") end"
      "$x.root.database.server.\"#text\" | if . then . else halt_error(\"TOML to XML conversion failed: missing root.database.server.#text\") end"
    ];
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
