# Remove a layer of attrset nesting, prefixing the outer names to the inner ones
{ die, lib }:

with lib;
attrs: listToAttrs
         (concatLists
           (mapAttrsToList (outer: mapAttrsToList
                                     (inner: value: {
                                       inherit value;
                                       name = outer + inner;
                                     }))
                                   attrs))
