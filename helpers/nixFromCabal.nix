{ composeWithArgs, haskellSrc2nix, isCallable, lib }:

with builtins; with lib;

# Make a Nix package definition from a Cabal project. The result is a function,
# accepting its dependencies as named arguments, returning a derivation. This
# allows mechanisms like "haskellPackages.callPackage" to select the appropriate
# dependencies for this version of GHC, etc.

# "src_" is the path to the Cabal project (this could be checked out via
# fetchgit or similar)

# f is a function for transforming the resulting derivation, e.g. it might
# override some aspects. If "f" is "null", we use the package as-is. Otherwise,
# we perform a tricky piece of indirection which essentially composes "f" with
# the package definition, but also preserves all of the named arguments required
# for "haskellPackages.callPackage" to work.
{
  def = src_: f:

  assert trace (toJSON {
    inherit src_;
    warning  = "deprecated";
    function = "nixFromCabal";
    message  = ''
      nixFromCabal is overly complex, does too much and can be replaced with other
      functions. In particular:
        - nixpkgs functions like hackage2nix and haskellSrc2nix can make a Nix
          function from a Cabal project.
        - We also define runCabal2nix to do this, but that may also get deprecated
          now that nixpkgs has this functionality.
        - Running a function whilst preserving names can be achieved using the
          withArgs, withArgsOf or composeWithArgs functions.
    '';
  }) true;
  assert typeOf src_ == "path" || isString src_ || isAttrs src_;
  assert isAttrs src_ || pathExists (if hasPrefix storeDir (unsafeDiscardStringContext src_)
                                        then src_
                                        else "${src_}");
  assert f == null || isCallable f;

  let src  = if isAttrs src_ then src_ else unsafeDiscardStringContext src_;

      name = let
        # Find the .cabal file and read properties from it
        getField = f: replaceStrings [f (toLower f)] ["" ""]
                                     (head (filter (l: hasPrefix          f  l ||
                                                       hasPrefix (toLower f) l)
                                                   cabalC));
        cabalC   = map (replaceStrings [" " "\t"] ["" ""])
                       (splitString "\n" (readFile (src + "/${cabalF}")));
        cabalF   = head (filter (x: hasSuffix ".cabal" x)
                                (attrNames (readDir src)));

        in unsafeDiscardStringContext (getField "Name:");

      nixed = haskellSrc2nix { inherit name src; };
      result = import "${nixed}";
  in

  # If we've been given a function "f", compose it with "result" using our
  # special-purpose function
  if f == null then result
               else composeWithArgs f result;

  tests = {};
}
