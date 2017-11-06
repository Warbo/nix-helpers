{}:

prefer: fallback: if (builtins.tryEval prefer).success
                     then prefer
                     else fallback
