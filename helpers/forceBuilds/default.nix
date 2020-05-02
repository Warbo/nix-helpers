# Forces the given derivations to be built and returns true if they work
{ withDeps, writeScript }:

drvs: import (withDeps drvs (writeScript "force" "true"))
