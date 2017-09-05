{ hackagePackageNamesDrv, jq, runCommand }:

import (runCommand "hackage-package-names.nix"
  {
    inherit hackagePackageNamesDrv;
    buildInputs = [ jq ];
  }
  ''
    jq -R '.' < "$hackagePackageNamesDrv" | jq -s '.' | tr -d ',' > "$out"
  '')
