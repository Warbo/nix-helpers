{
  diffutils,
  jq,
  runCommand,
  runJq,
  toml-sort,
  xmlstarlet,
  yamlfix,
  yq,
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

  normaliseToml =
    name: toml:
    runCommand "normalised-${name}.toml"
      {
        inherit toml;
        buildInputs = [ toml-sort ];
      }
      ''
        toml-sort -a --no-comments < "$toml" > "$out"
      '';

  normaliseXml =
    name: xml:
    runCommand "normalised-${name}.xml"
      {
        inherit xml;
        buildInputs = [ xmlstarlet ];
      }
      ''
        < "$xml" \
          xmlstarlet ed -d "//comment()" |
          xmlstarlet ed -d "//processing-instruction()" |
          xmlstarlet format > "$out"
      '';

  normaliseYaml =
    # Uses 'yq -Y' to strip comments but preserve the rest as much as possible
    name: yaml:
    runCommand "normalised-${name}.yaml" {
      inherit yaml;
      buildInputs = [ yamlfix yq ];
    } ''< "$yaml" yq -Y '.' | yamlfix - > "$out"'';

  # TOML can't represent null, so this is useful to filter them out
  noNulls = ''
    def remove_nulls:
      if type == "object" then
        with_entries(select(.value != null) | .value |= remove_nulls)
      elif type == "array" then
        map(select(. != null) | remove_nulls)
      else
        .
      end;

    remove_nulls
  '';

  # Various notions of equality/equivalence since each encoding can be formatted
  # in ways that don't affect the meaning.

  sameBy = normalise: label: x: y:
    runCommand "${label}-are-same"
      {
        x = normalise "${label}-x" x;
        y = normalise "${label}-y" y;
        buildInputs = [ diffutils ];
      }
      ''
        if cmp "$x" "$y"
        then
          mkdir "$out"
        else
          diff "$x" "$y"
        fi
      '';

  same = sameBy (_: x: x);
  sameJson = sameBy normaliseJson;
  sameToml = sameBy normaliseToml;
  sameXml = sameBy normaliseXml;
  sameYaml = sameBy normaliseYaml;

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
    sameJson "json-to-json-identity" exampleJsonFile (run {
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
      ''$x.string_example | if . then empty else ("missing string_example" | halt_error) end''
      ''$x.integer_example | if . then empty else ("missing integer_example" | halt_error) end''
      ''$x.array_example | if (type == "array") then empty else ("array_example is not an array" | halt_error) end''
      ''$x.object_example | if (type == "object") then empty else ("object_example is not an object" | halt_error) end''
    ];
  };

  json-to-xml = run {
    name = "json-to-xml-check";
    inputFile = run {
      name = "json-to-xml-output";
      inputFile = exampleJsonFile;
      from = "json";
      to = "xml";
      outArgs = ["--xml-root" "root"];
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ''. as $x''
      ''$x.root.string_example | if . then empty else ("missing root.string_example" | halt_error) end''
      ''$x.root.integer_example | if . then empty else ("missing root.integer_example" | halt_error) end''
      ''$x.root.array_example | if (type == "array") then empty else ("root.array_example is not an array" | halt_error) end''
      ''$x.root.object_example | if (type == "object") then empty else ("root.object_example is not an object" | halt_error) end''
    ];
  };

  json-to-toml = run {
    name = "json-to-toml-check";
    inputFile = run {
      name = "json-to-toml-output";
      inputFile = exampleJsonFile;
      from = "json";
      to = "toml";
      filter = noNulls;
    };
    from = "toml";
    to = "json";
    # Check for presence of simple types that TOML can represent
    filter = [
      ''. as $x''
      ''$x.string_example | if . then empty else ("missing string_example" | halt_error) end''
      ''$x.integer_example | if . then empty else ("missing integer_example" | halt_error) end''
      ''$x.float_example | if . then empty else ("missing float_example" | halt_error) end''
      ''$x.boolean_true | if (type == "boolean") then empty else ("boolean_true is not a boolean" | halt_error) end''
      ''$x.boolean_false | if (type == "boolean") then empty else ("boolean_false is not a boolean" | halt_error) end''
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
  yaml-to-json = sameJson "yaml-to-json"
    (run {
      name = "yaml-to-json-intermediate";
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "json";
      filter = ".";
    })
    (run {
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "json";
      filter = ".";
    });

  # Some discrepancies
  # yaml-to-yaml-identity = sameYaml "yaml-to-yaml-identity"
  #   exampleYamlFile
  #   (run {
  #     inputFile = exampleYamlFile;
  #     from = "yaml";
  #     to = "yaml";
  #     filter = ".";
  #   });

  # YAML to other formats (check conversion by converting back to JSON)
  yaml-to-xml = run {
    name = "yaml-to-xml-check";
    inputFile = run {
      name = "yaml-to-xml-output";
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "xml";
      outArgs = ["--xml-root" "root"];
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ''. as $x''
      ''$x.root.string_key | if . then empty else ("missing root.string_key" | halt_error) end''
      ''$x.root.integer_key | if . then empty else ("missing root.integer_key" | halt_error) end''
      ''$x.root.list_of_strings | if (type == "array") then empty else ("root.list_of_strings is not an array" | halt_error) end''
      ''$x.root.nested_map | if (type == "object") then empty else ("root.nested_map is not an object" | halt_error) end''
    ];
  };

  yaml-to-toml = run {
    name = "yaml-to-toml-check";
    inputFile = run {
      name = "yaml-to-toml-output";
      inputFile = exampleYamlFile;
      from = "yaml";
      to = "toml";
      filter = noNulls;
    };
    from = "toml";
    to = "json";
    # Check for presence of key elements that TOML can represent
    filter = [
      ''. as $x''
      ''$x.string_key | if . then empty else ("missing string_key" | halt_error) end''
      ''$x.integer_key | if . then empty else ("missing integer_key" | halt_error) end''
      ''$x.float_key | if . then empty else ("missing float_key" | halt_error) end''
      ''$x.boolean_true | if (type == "boolean") then empty else ("boolean_true is not a boolean" | halt_error) end''
      ''$x.boolean_false | if (type == "boolean") then empty else ("boolean_false is not a boolean" | halt_error) end''
      ''$x.list_of_numbers | if (type == "array") then empty else ("list_of_numbers is not an array" | halt_error) end''
      ''$x.nested_map.level1.level2.key | if . then empty else ("missing nested_map.level1.level2.key" | halt_error) end''
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
  xml-to-json = sameJson "xml-to-json"
    (run {
      name = "xml-to-json-intermediate";
      inputFile = exampleXmlFile;
      from = "xml";
      to = "json";
      filter = ".";
    })
    (run {
      inputFile = exampleXmlFile;
      from = "xml";
      to = "json";
      filter = ".";
    });

  # XML->XML doesn't preserve processing instructions, the position of child
  # elements within text, CDATA wrappers, or the presence of whitespace.
  # xml-to-xml-identity = sameXml "xml-to-xml-identity"
  #   exampleXmlFile
  #   (run {
  #     inputFile = exampleXmlFile;
  #     from = "xml";
  #     to = "xml";
  #     filter = ".";
  #   });

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
      ''. as $x''
      ''$x.root.element1 | if . then empty else ("missing root.element1" | halt_error) end''
      ''$x.root.element1."@attribute1" | if . then empty else ("missing root.element1.@attribute1" | halt_error) end''
      ''$x.root.element2."test:namespacedElement" | if . then empty else ("missing root.element2.test:namespacedElement" | halt_error) end''
      ''$x.root.element3 | if . then empty else ("missing root.element3" | halt_error) end''
    ];
  };

  xml-to-toml = run {
    name = "xml-to-toml-check";
    inputFile = run {
      name = "xml-to-toml-output";
      inputFile = exampleXmlFile;
      from = "xml";
      to = "toml";
      filter = noNulls;
    };
    from = "toml";
    to = "json";
    filter = [
      ''. as $x''
      ''$x.root.element1 | if . then empty else ("missing root.element1" | halt_error) end''
      ''$x.root.element1."@attribute1" | if . then empty else ("missing root.element1.@attribute1" | halt_error) end''
      ''$x.root.element2."test:namespacedElement" | if . then empty else ("missing root.element2.test:namespacedElement" | halt_error) end''
    ];
  };

  xml-filter-specific =
    sameJson "xml-filter-specific" exampleXmlFilteredExpected
      (run {
        inputFile = exampleXmlFile;
        from = "xml";
        to = "json";
        filter = ''.root.element1."#text"'';
      });

  # normaliseToml doesn't make things canonical (e.g. 'foo\bar' vs "foo\\bar")
  # toml-to-toml-identity = sameToml "toml-to-toml-identity"
  #   exampleTomlFile
  #   (run {
  #     name = "toml-to-json-intermediate-for-identity";
  #     inputFile = exampleTomlFile;
  #     from = "toml";
  #     to = "toml";
  #     filter = ".";
  #   });

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
      ''. as $x''
      ''$x.string | if . then empty else ("missing string" | halt_error) end''
      ''$x.integer | if . then empty else ("missing integer" | halt_error) end''
      ''$x.float | if . then empty else ("missing float" | halt_error) end''
      ''$x.boolean_true | if (type == "boolean") then empty else ("boolean_true is not a boolean" | halt_error) end''
      ''$x.boolean_false | if (type == "boolean") then empty else ("boolean_false is not a boolean" | halt_error) end''
      ''$x.simple_array | if (type == "array") then empty else ("simple_array is not an array" | halt_error) end''
      ''$x.owner.name | if . then empty else ("missing owner.name" | halt_error) end''
      ''$x.database.server | if . then empty else ("missing database.server" | halt_error) end''
    ];
  };

  toml-to-xml = run {
    name = "toml-to-xml-check";
    inputFile = run {
      name = "toml-to-xml-output";
      inputFile = exampleTomlFile;
      from = "toml";
      to = "xml";
      outArgs = ["--xml-root" "root"];
      filter = ".";
    };
    from = "xml";
    to = "json";
    # Check for presence of key elements in the XML-to-JSON structure
    filter = [
      ''. as $x''
      ''$x.root.string | if . then empty else ("missing root.string" | halt_error) end''
      ''$x.root.integer | if . then empty else ("missing root.integer" | halt_error) end''
      ''$x.root.float | if . then empty else ("missing root.float" | halt_error) end''
      ''$x.root.boolean_true | if (type == "boolean") then empty else ("root.boolean_true is not a boolean" | halt_error) end''
      ''$x.root.boolean_false | if (type == "boolean") then empty else ("root.boolean_false is not a boolean" | halt_error) end''
      ''$x.root.simple_array | if (type == "array") then empty else ("root.simple_array is not an array" | halt_error) end''
      ''$x.root.owner.name | if . then empty else ("missing root.owner.name" | halt_error) end''
      ''$x.root.database.server | if . then empty else ("missing root.database.server" | halt_error) end''
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
  json-extra-args = sameJson "json-extra-args" exampleJsonFile (run {
    inputFile = exampleJsonFile;
    from = "json";
    to = "json";
    filter = ".";
    extraArgs = [ "--compact-output" ]; # Example extra arg for jq
  });
}
