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
      "$x.string_example | if . then empty else \"missing string_example\" end | halt_error"
      "$x.integer_example | if . then empty else \"missing integer_example\" end | halt_error"
      "$x.array_example | if (is_array) then empty else \"array_example is not an array\") end | halt_error"
      "$x.object_example | if (is_object) then empty else \"object_example is not an object\") end | halt_error"
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
      "$x.root.string_example.\"#text\" | if . then empty else \"missing root.string_example.#text\" end | halt_error"
      "$x.root.integer_example.\"#text\" | if . then empty else \"missing root.integer_example.#text\" end | halt_error"
      "$x.root.array_example | if (is_array) then empty else \"root.array_example is not an array\") end | halt_error"
      "$x.root.object_example | if (is_object) then empty else \"root.object_example is not an object\") end | halt_error"
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
      "$x.string_example | if . then empty else \"missing string_example\" end | halt_error"
      "$x.integer_example | if . then empty else \"missing integer_example\" end | halt_error"
      "$x.float_example | if . then empty else \"missing float_example\" end | halt_error"
      "$x.boolean_true | if (is_boolean) then empty else \"boolean_true is not a boolean\") end | halt_error"
      "$x.boolean_false | if (is_boolean) then empty else \"boolean_false is not a boolean\") end | halt_error"
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
      "$x.root.string_key.\"#text\" | if . then empty else \"missing root.string_key.#text\" end | halt_error"
      "$x.root.integer_key.\"#text\" | if . then empty else \"missing root.integer_key.#text\" end | halt_error"
      "$x.root.list_of_strings | if (is_array) then empty else \"root.list_of_strings is not an array\") end | halt_error"
      "$x.root.nested_map | if (is_object) then empty else \"root.nested_map is not an object\") end | halt_error"
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
      "$x.string_key | if . then empty else \"missing string_key\" end | halt_error"
      "$x.integer_key | if . then empty else \"missing integer_key\" end | halt_error"
      "$x.float_key | if . then empty else \"missing float_key\" end | halt_error"
      "$x.boolean_true | if (is_boolean) then empty else \"boolean_true is not a boolean\") end | halt_error"
      "$x.boolean_false | if (is_boolean) then empty else \"boolean_false is not a boolean\") end | halt_error"
      "$x.list_of_numbers | if (is_array) then empty else \"list_of_numbers is not an array\") end | halt_error"
      "$x.nested_map.level1.level2.key | if . then empty else \"missing nested_map.level1.level2.key\" end | halt_error"
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
      "$x.root.element1.\"#text\" | if . then empty else \"missing root.element1.#text\" end | halt_error"
      "$x.root.element1.\"@attribute1\" | if . then empty else \"missing root.element1.@attribute1\" end | halt_error"
      "$x.root.element2.\"test:namespacedElement\".\"#text\" | if . then empty else \"missing root.element2.test:namespacedElement.#text\" end | halt_error"
      "$x.root.element3.\"#text\" | if . then empty else \"missing root.element3.#text\" end | halt_error"
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
      "$x.root.element1.\"#text\" | if . then empty else \"missing root.element1.#text\" end | halt_error"
      "$x.root.element1.\"@attribute1\" | if . then empty else \"missing root.element1.@attribute1\" end | halt_error"
      "$x.root.element2.\"test:namespacedElement\".\"#text\" | if . then empty else \"missing root.element2.test:namespacedElement.#text\" end | halt_error"
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
      "$x.string | if . then empty else \"missing string\" end | halt_error"
      "$x.integer | if . then empty else \"missing integer\" end | halt_error"
      "$x.float | if . then empty else \"missing float\" end | halt_error"
      "$x.boolean_true | if (is_boolean) then empty else \"boolean_true is not a boolean\") end | halt_error"
      "$x.boolean_false | if (is_boolean) then empty else \"boolean_false is not a boolean\") end | halt_error"
      "$x.simple_array | if (is_array) then empty else \"simple_array is not an array\") end | halt_error"
      "$x.owner.name | if . then empty else \"missing owner.name\" end | halt_error"
      "$x.database.server | if . then empty else \"missing database.server\" end | halt_error"
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
      "$x.root.string.\"#text\" | if . then empty else \"missing root.string.#text\" end | halt_error"
      "$x.root.integer.\"#text\" | if . then empty else \"missing root.integer.#text\" end | halt_error"
      "$x.root.float.\"#text\" | if . then empty else \"missing root.float.#text\" end | halt_error"
      "$x.root.boolean_true | if (is_boolean) then empty else \"root.boolean_true is not a boolean\") end | halt_error"
      "$x.root.boolean_false | if (is_boolean) then empty else \"root.boolean_false is not a boolean\") end | halt_error"
      "$x.root.simple_array | if (is_array) then empty else \"root.simple_array is not an array\") end | halt_error"
      "$x.root.owner.name.\"#text\" | if . then empty else \"missing root.owner.name.#text\" end | halt_error"
      "$x.root.database.server.\"#text\" | if . then empty else \"missing root.database.server.#text\" end | halt_error"
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
