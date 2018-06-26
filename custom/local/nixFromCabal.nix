self: super:

with builtins; with self.lib;

# Make a Nix package definition from a Cabal project. The result is a function,
# accepting its dependencies as named arguments, returning a derivation. This
# allows mechanisms like "haskellPackages.callPackage" to select the appropriate
# dependencies for this version of GHC, etc.

# "dir" is the path to the Cabal project (this could be checked out via fetchgit
# or similar)

# f is a function for transforming the resulting derivation, e.g. it might
# override some aspects. If "f" is "null", we use the package as-is. Otherwise,
# we perform a tricky piece of indirection which essentially composes "f" with
# the package definition, but also preserves all of the named arguments required
# for "haskellPackages.callPackage" to work.

{

nixFromCabal = src_: f:

assert typeOf src_ == "path" || isString src_ || isAttrs src_;
assert isAttrs src_ || pathExists (if hasPrefix storeDir (unsafeDiscardStringContext src_)
                                      then src_
                                      else "${src_}");
assert f == null || isFunction f;

let dir      = if isAttrs src_ then src_ else unsafeDiscardStringContext src_;
    hsVer    = self.haskellPackages.ghc.version;

    fields   = let
      # Find the .cabal file and read properties from it
      getField = f: replaceStrings [f (toLower f)] ["" ""]
                                   (head (filter (l: hasPrefix          f  l ||
                                                     hasPrefix (toLower f) l)
                                                 cabalC));
      cabalC   = map (replaceStrings [" " "\t"] ["" ""])
                     (splitString "\n" (readFile (dir + "/${cabalF}")));
      cabalF   = head (filter (x: hasSuffix ".cabal" x)
                              (attrNames (readDir dir)));

      pkgName = unsafeDiscardStringContext (getField "Name:");
      pkgV    = unsafeDiscardStringContext (getField "Version:");

      # Read properties from derivation
      #drvName = dir
      in { name = pkgName; version = pkgV; };

    # Produces a copy of the dir contents, along with a default.nix file
    nixed = self.runCommand "nix-haskell"
      {
        inherit dir;
        name             = "nixFromCabal-${hsVer}-${fields.name}-${fields.version}";
        preferLocalBuild = true; # We need dir to exist
        buildInputs      = [
          self.cabal2nix
          self.glibc  # For iconv
        ];
      }
      ''
        source $stdenv/setup

        echo "Copying '$dir' to '$out'"
        cp -r "$dir" "$out"
        cd "$out"

        echo "Setting permissions"
        chmod -R +w . # We need this if dir has come from the store

        echo "Cleaning up unnecessary files"
        rm -rf ".git" || true

        echo "Creating '$out/default.nix'"
        touch default.nix
        chmod +w default.nix

        echo "Stripping unicode from .cabal"
        for F in *.cabal
        do
          CONTENT=$(iconv -c -f utf-8 -t ascii "$F")
          echo "$CONTENT" > "$F"
        done

        echo "Generating package definition"
        cabal2nix ./. > default.nix
      '';
    result = import "${nixed}";
in

# If we've been given a function "f", compose it with "result" using our
# special-purpose function
if f == null then result
             else self.composeWithArgs f result;

}
