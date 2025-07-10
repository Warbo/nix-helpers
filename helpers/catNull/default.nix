# Removes null values from a list
{}:
builtins.concatMap (x: if x == null then [] else [x])
