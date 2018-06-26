{ callPackage, nodePackages, runCommand }:

repo:
  with rec {
    inherit callPackage nodePackages runCommand;

    converted = runCommand "convert-npm"
      {
        inherit repo;
        buildInputs = [ nodePackages.node2nix ];
      }
      ''
        cp -r "$repo" "$out"
        chmod +w -R "$out"
        cd "$out"
        node2nix
      '';

    generatedPackages = callPackage "${converted}" {};
  };
  generatedPackages.package
