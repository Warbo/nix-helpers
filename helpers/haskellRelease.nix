# Useful for release.nix files in Haskell projects
{ cabalField, customised, fail, haskellPkgDepsDrv, lib, nix, runCabal2nix,
  runCommand, self, stableVersion, unpack, withDeps, withNix, writeScript }:

with builtins;
with lib;
with rec {
  getNix = v: getAttr v (self // { inherit (customised) unstable; });

  # Make the nixVersion attr (if kept) a set of all its Haskell versions
  buildForNixpkgs = keep: hs: nixVersion: if !(keep nixVersion) then "" else ''
    #
      "${nixVersion}" =
        with {
          nixpkgs = ${nixVersion} // {
            # Avoid https://github.com/haskell/zlib/issues/11
            # FIXME: Add tests to ensure that this is still needed
            zlib = ${nixVersion}.callPackage
                     (repo1609 + "/pkgs/development/libraries/zlib") {};
          };
        };
        with nixpkgs.haskell;
        {
          ${concatStringsSep "\n"
              (map hs (attrNames (getNix nixVersion).haskell.packages))}
        };
    '';

  # Make the hsVersion attr (if kept) a set with nixpkgs and hackage builds
  buildForHaskell = keep: hsVersion: if !(keep hsVersion) then "" else ''
    #
          "${hsVersion}" = go {
            inherit nixpkgs;
            haskellPackages = packages."${hsVersion}";
          };
  '';

  # Defines nixpkgs and hackageb uilds, using a given haskellPackages set
  pkgExpr = { cabal-args ? null, dir, name }: runCommand "${name}-expr"
    {
      # Bare function, which we'll give arguments from the nixpkgs Haskell set
      nixpkgsDeps = runCabal2nix { url = dir; };

      # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
      hackageDeps = haskellPkgDepsDrv ((if cabal-args == null
                                           then {}
                                           else { inherit cabal-args; }) // {
                                        inherit dir;
                                      });

      default = writeScript "${name}-default.nix" ''
        { haskellPackages, nixpkgs }:

        with builtins;
        with (import <nixpkgs> { config = {}; }).lib;
        with rec {
          depNames = import ./deps;

          # Calls the Haskell package defined by the given file with dummy
          # arguments, to see which arguments should come from nixpkgs and which
          # from haskellPackages (self). Uses this info to call the package
          # "properly". This is especially useful for args like 'zlib', which
          # could be from either.
          callProperly = self: file:
            with rec {
              func    = import file;
              args    = attrNames (functionArgs func);
              dummies = listToAttrs (map (x: { name = x; value = x; }) args);
              sysArgs = func (dummies // {
                mkDerivation = args: args.librarySystemDepends or [];
              });
              sysPkgs = listToAttrs
                (map (name: { inherit name; value = getAttr name nixpkgs; })
                     sysArgs);
            };
            self.callPackage func sysPkgs;

          overrides = self: super: genAttrs depNames
            (name: callProperly self (./deps/pkgs + ("/" + name + ".nix")));

          hsPkgs = haskellPackages.override { inherit overrides; };
        };
        {
          hackageDeps = hsPkgs.${name};
          nixpkgsDeps = callProperly haskellPackages ./fromCabal2nix.nix;
        }
      '';
    }
    ''
      mkdir "$out"
      cp -r "$hackageDeps" "$out/deps"
      cp    "$nixpkgsDeps" "$out/fromCabal2nix.nix"
      cp "$default" "$out/default.nix"
    '';

  go = {
    cabal-args  ? null,       # Extra args for 'cabal install'
    dir,                      # Directory of a Haskell project
    name        ? null,       # Taken from .cabal file if not given
    haskellKeep ? (x: true),  # Predicate for which Haskell/GHC versions to use
    nixKeep     ? (x: true)   # Predicate for which nixpkgs versions to use
  }:
    with {
      pName = if name == null
                 then cabalField { inherit dir; field = "name"; }
                 else name;
    };
    # FIXME: This should use <nix-config> and <nixpkgs> if available. We could
    # still use ../.. to access a helper function to make that easier.
    # Defines builds for (kept) Haskell versions for (kept) nixpkgs versions
    writeScript "${pName}-release.nix" ''
      with import ${../..} {};
      with {
        go = import ${pkgExpr {
                      inherit cabal-args dir;
                      name = pName;
                    }};
      };
      {
        ${concatStringsSep "\n"
            (map (buildForNixpkgs nixKeep (buildForHaskell haskellKeep))
                 (attrNames customised))}
      }
    '';

  # Check that this system works for some common, and some problematic, Haskell
  # packages
  tests =
    with rec {
      hsVersion = "ghc802";

      getPkg    = name: attrByPath
                          [ stableVersion "haskell" "packages" hsVersion name ]
                          (abort "Missing package ${name}")
                          self;

      getResult = name: go {
        inherit name;
        cabal-args  = [];  # Avoid tests, to prevent cycles
        dir         = unpack (getPkg name).src;
        haskellKeep = v: v == hsVersion;
        nixKeep     = v: v == stableVersion;
      };

      check = name: runCommand "check-haskellRelease"
        (withNix {
          inherit hsVersion;
          buildInputs = [ fail nix ];
          result      = getResult name;
          stable      = stableVersion;
        })
        ''
          function check {
            nix-instantiate --eval --read-write-mode \
              -E "with builtins; with { lhs = $1; rhs = $2; };"'
                  assert lhs == rhs || trace (toJSON { inherit lhs rhs; })
                                             false;
                  true'
          }

          check "typeOf (import $result)" '"set"' ||
            fail "Generated release.nix doen't define a set"

          check "attrNames (import $result)" "[ \"$stable\" ]" ||
            fail "Should have one attribute, with stable name '$stable'"

          check "attrNames (import $result).$stable" "[\"$hsVersion\"]" ||
            fail "Set should have one GHC version, namely '$hsVersion'"

          check "(import $result).$stable.$hsVersion ? hackageDeps" "true" ||
            fail "Should have a 'hackageDeps' attribute"

          check "(import $result).$stable.$hsVersion ? nixpkgsDeps" "true" ||
            fail "Should have a 'nixpkgsDeps' attribute"

          function build {
            echo "Attempting to build '$1' package" 1>&2
            if nix-build --show-trace --no-out-link \
                 -E "(import $result).$stable.$hsVersion.$1"
            then
              echo "Successfully built '$1' package" 1>&2
            else
              fail "Couldn't build '$1' package"
            fi
          }

          # Build in $out so that results aren't garbage collected too early
          mkdir "$out"
          cd "$out"
          build "hackageDeps"
          build "nixpkgsDeps"
        '';
    };
    {
      # A widely-used Haskell package, see if it works
      text = check "text";

      # zlib is awkward, since it's both a Haskell package and a system package
      zlib = check "zlib";

      # digest also depends on the system's zlib
      digest = check "digest";

      # This depends on the Haskell zlib package, rather than the system one
      zlib-bindings = check "zlib-bindings";
    };
};
args: withDeps (attrValues tests) (go args)
