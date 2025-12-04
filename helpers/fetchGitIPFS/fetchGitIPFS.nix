/*
  fetchGitIPFS.nix version >= 2025-12-02T12:00:00Z

  This file provides a Nix function called 'fetchGitIPFS' to fetch Git trees
  from IPFS HTTP gateways. It has the following design goals:

   - Be easily fetched from IPFS. Hence it's all in one self-contained file.
   - Be usable from a bare Nix expression. In particular, no dependencies need
     to be passed in (whether as function arguments, or impurely like <nixpkgs>)
   - Allow dependencies to be passed in, to override any baked-in defaults.
     These are optional arguments, to avoid conflicting with the previous goal.
   - Avoid relying on URLs. Support fallbacks, overrides and caches.
   - Be relatively stable and unchanging.
     - It's easier to fetch from IPFS when seeding resources aren't spread
       across many different versions.
     - Allowing dependencies to be overridden helps, since those can be updated
       by users as desired, rather than bumping version numbers in this script.
     - Supporting fallbacks, overrides and caches allows this script to keep on
       working, even after hosts have shut down, domains have expired, etc.

  Here's an example usage, for "bootstrapping" project dependencies from IPFS:

      with rec {
        fetchGitIPFS = import (builtins.fetchTree {
          type = "file";
          url = "https://ipfs.io/ipfs/CID_OF_THIS_FILE";
          narHash = NAR_HASH_OF_THIS_FILE;
        });
        inherit (fetchGitIPFS {
                  mkPkgs = { fetchGitIPFS, ... }:
                    import (fetchGitIPFS { sha1 = MY_NIXPKGS_TREE_ID; })
                      { config = {}; overlays = []; };
                  sha1 = {
                    myFirstDependency = ITS_GIT_TREE_ID;
                    mySecondDependency = ITS_GIT_TREE_ID;
                  };
                })
          myFirstDependency mySecondDependency pkgs;
      };
      ...

  In principle, fetching this file from IPFS allows anyone to contribute to its
  hosting; and to resurrect files which have otherwise disappeared.
  Unfortunately, none of Nix's builtin fetchers support fallback URLs (as of
  version 2.26); so we recommend the (commonly used) ipfs.io gateway, along with
  'import <nix/fetchurl.nix>' and a 'hash'. This combination lets Nix query its
  caches first; which, in principle, gives anyone a mechanism to bypass the
  ipfs.io URL and resurrect this file if it disappears, e.g. by fetching it from
  another IPFS node or gateway, and manually inserting it into their
  store/cache.

  The fetchFromIPFS function defined in this file defaults to querying a local
  IPFS gateway, which explicitly avoids dependency on a third-party. In the
  common case that there is no local gateway, it falls back to an overridable
  list of public gateways, to further reduce reliance on a single domain. It
  also relies on Fixed Output Derivations (FODs), which can be fetched from Nix
  caches without needing IPFS; and are also robust to changes in their
  implementation (since they are identified by output hash, so their inputs can
  vary without invalidating any cached copies).

  ## Fetching Git trees ##

  The result of importing this file is a "functor" (an attrset which can be
  called as if it were a lambda), which is the fetchGitIPFS function. It can be
  called in several ways, depending on what's most convenient. In every case, an
  attrset must be given as argument: all attributes are optional.

  If the 'sha1' argument is a string containing the SHA1 of a Git tree, written
  in hex, like 'sha1 = "f4527832148dd6894fe856fde1c65df822a7529d";' then the
  result will be a fixed-output derivation (FOD) for fetching that Git tree from
  IPFS.

  Instead of 'sha1' we can give 'sha256': this is supported by Git, but Nix does
  not yet support git-hashing with SHA256 (as of Nix 2.26). Finally, a 'hash'
  argument can be given instead, which is parsed by Nix's 'convertHash' function
  (allowing SRI format, etc.).

  Only one 'sha1', 'sha256' or 'hash' string can be given, to avoid ambiguity.
  If you want to fetch multiple trees, wrap the hashes in attrsets: those can be
  nested to any depth, but to avoid ambiguity the "path" of each string/hash
  must be unique, e.g. '{ sha1.foo.bar = "..."; hash.foo.bar = "..."; }' is not
  allowed but '{ sha1.foo.bar = "..."; hash.foo.baz = "..."; }' is fine.

  ## The result ##

  If a string is given for 'sha1', 'sha256' or 'hash' then the result is a FOD
  for that Git tree.

  If 'sha1', 'sha256' or 'hash' was an attrset, then the result will contain a
  FOD for each of their strings/hashes; structured in the same way; hence the
  example above would contain a FOD at 'foo.bar' and another at 'foo.baz'. This
  also works when the whole result is a FOD, e.g. '{ sha1 = "..."; hash.foo =
  "..."; }' will result in a FOD, and there will be another in its 'foo'
  attribute.

  The result will always contain a 'fetchGitIPFS' attribute. Normally its value
  is the fetchGitIPFS function, though it can get replaced e.g. if we used input
  like 'sha1.fetchGitIPFS = "...";'. If any overrides were given (see section
  below), then the resulting function will use those values as its defaults.
  This is useful for specialising the fetchGitIPFS function, to avoid having to
  override it at every call site; for example:

      with { inherit (import THIS_FILE { pkgs = myPkgs; }) fetchGitIPFS; };
      fetchGitIPFS { sha1 = "..."; }  # Takes dependencies from myPkgs

  If the output is not a FOD (i.e. it was not given a string for 'sha1',
  'sha256' or 'hash') then the same 'fetchGitIPFS' value is available as
  '__functor'. This allows the result to be called directly as a function. Note
  that an attrset with a '__functor' attribute will not be built by the
  'nix-build' command, since it's considered to be a function rather than a
  derivation or set of derivations. This is why we do not include '__functor'
  when the result is a FOD.

  Finally, a 'pkgs' attribute is included. As long as it's not been replaced
  (e.g.  by giving 'sha1.pkgs = "...";') then its value will be the Nixpkgs
  attribute set used for the dependencies of fetchGitIPFS. This defaults to a
  pinned version, but can be overridden (see section below). We include this in
  the output so overrides calling fetchGitIPFS recursively don't repeat, like
  { mkPkgs = { fetchGitIPFS }: import (fetchGitIPFS ...) {}; sha1.pkgs = ...; }
  Alternatively, we can use the default 'pkgs' as is, if we don't want to pin
  our own version; e.g.

      with rec {
        inherit (import THIS_FILE { sha1.deps.a = "..."; sha1.deps.b = "..."; })
          deps pkgs;
        defaultPkgs = pkgs;
      };
      { pkgs ? defaultPkgs, a ? deps.a, b ? deps.b }: pkgs.mkStdDerivation {...}

  ## Overriding implementation details ##

  Providing an argument called 'gateways', as a list of strings, will cause
  fetchGitIPFS to try fetching its CAR files from those URLs, in order. If not
  provided, a default list of gateways will be tried; starting with
  "http://127.0.0.1:8080" (a local gateway) then "https://ipfs.io" (a commonly
  used public gateway).

  If we have a Nixpkgs attrset (e.g. imported from <nixpkgs>), give it as a
  'pkgs' argument to have fetchGitIPFS use it instead of its built-in default.
  It will also be returned in a 'pkgs' attribute (unless replaced by a hash with
  the same name). Overriding 'pkgs' is useful to avoid having multiple
  out-of-date copies of Nixpkgs on your system. If you don't have a Nixpkgs
  attrset available, and want to get one using fetchGitIPFS itself, then provide
  a 'mkPkgs' argument instead (e.g. like the examples above). To avoid infinite
  recursion, the 'fetchGitIPFS' argument given to 'mkPkgs' uses the default
  pkgs, so may cause that to be downloaded; however, that can be
  garbage-collected once the desired Nixpkgs has been "bootstrapped" into your
  store or a cache.

  fetchGitIPFS uses a program called go-car which is not provided by its default
  pkgs attrset. A specific implementation can be given via the 'go-car'
  argument; or a 'mkGoCar' argument can be given as a function from
  '{ pkgs, fetchGitIPFS }' to a go-car implementation. The default 'mkGoCar'
  will return 'pkgs.go-car', if that exists; or otherwise use 'pkgs' to build a
  particular version. Its 'pkgs' argument will be the overridden version, so you
  can also use 'pkgs' or 'mkPkgs' to provide a 'go-car' attribute, instead of
  overriding 'go-car' or 'mkGoCar'.
*/
with rec {
  inherit (builtins)
    attrNames
    attrValues
    concatLists
    convertHash
    elem
    filter
    getAttr
    hasAttr
    head
    length
    mapAttrs
    split
    toJSON
    typeOf
    ;

  fetchOne =
    {
      pkgs,
      gateways,
      go-car,
    }:
    {
      sha1 ? null,
      sha256 ? null,
      hash ? null,
    }:
    assert
      length (
        filter (x: x != null) [
          sha1
          sha256
          hash
        ]
      ) == 1
      || throw "fetchGitIPFS needs exactly one of sha1/sha256/hash, got ${
        toJSON { inherit sha1 sha256 hash; }
      }";
    with rec {
      sriHash = convertHash (
        {
          toHashFormat = "sri";
        }
        // (
          if sha1 == null then
            if sha256 == null then
              { inherit hash; }
            else
              {
                hash = sha256;
                hashAlgo = "sha256";
              }
          else
            {
              hash = sha1;
              hashAlgo = "sha1";
            }
        )
      );

      # Turn SRI hash into CID
      type = head (split "-" sriHash);
      hashCode = {
        sha256 = "1220";
        sha1 = "1114";
      };
      cid = "f0178${hashCode."${type}"}${
        convertHash {
          hash = sriHash;
          toHashFormat = "base16";
        }
      }";
    };
    (pkgs.fetchurl {
      name = cid;
      urls = map (base: "${base}/ipfs/${cid}?format=car") gateways;
      curlOptsList = [
        "-H"
        "Accept: application/vnd.ipld.car"
      ];
      recursiveHash = true;
      downloadToTemp = true;
      hash = sriHash;
      nativeBuildInputs = with pkgs; [
        git
        go-car
        kubo
        qpdf
      ];
      postFetch = ''
        # TODO: Gateway might give empty/incomplete CAR; try next URL?
        car inspect "$downloadedFile" |
          grep -q 'Root blocks present in data: Yes' || {
            echo "ERROR: CAR has no root (maybe the block was not found)"
            car inspect "$downloadedFile"
            false
          } 1>&2

        # Extract blocks from CAR into an empty git repo's objects dir
        git init --quiet
        while read -r CID
        do
          FULL=$(ipfs cid format -b base16 -f '%D' "$CID")
          DEST=".git/objects/$(echo "$FULL" | cut -c-2)/$(echo "$FULL" | cut -c3-)"
          mkdir -p "$(dirname "$DEST")"
          car get-block "$downloadedFile" "$CID" |
            zlib-flate -compress > "$DEST"
        done < <(car ls "$downloadedFile")

        # Realise git tree object in $out
        mkdir -p "$out"
        git archive "${
          convertHash {
            hash = sriHash;
            toHashFormat = "base16";
          }
        }" | tar -x -C "$out"
      '';
    }).overrideAttrs
      (_: {
        outputHashMode = "git";
      });

  fetchAll =
    {
      sha1 ? null,
      sha256 ? null,
      hash ? null,
      ...
    }:
    deps:
    with rec {
      inherit (deps.pkgs.lib.attrsets) recursiveUpdate;

      # Run fetchOne on all sha1s, sha256s and hashes
      toAttrs =
        type: _: arg:
        with { fetched = fetchOne deps { "${type}" = arg; }; };
        if arg == null then
          { }
        else if typeOf arg == "string" then
          fetched
        else if typeOf arg == "set" then
          mapAttrs (toAttrs type) arg
        else
          throw "Hashes should be strings or attrsets";
      sha1s = toAttrs "sha1" null sha1;
      sha256s = toAttrs "sha256" null sha256;
      hashes = toAttrs "hash" null hash;

      # Check for clashes between sha1/sha256/hash
      paths =
        prefix: name: value:
        if value == null then
          [ ]
        else if typeOf value == "set" then
          concatLists (attrValues (mapAttrs (paths (prefix ++ [ name ])) value))
        else
          [ (prefix ++ [ name ]) ];
      sha1Paths = paths [ ] null sha1;
      sha256Paths = paths [ ] null sha256;
      hashPaths = paths [ ] null hash;
      occuringIn = xs: ys: filter (p: elem p ys) xs;
      sha1Dupes = occuringIn sha1Paths (sha256Paths ++ hashPaths);
      sha256Dupes = occuringIn sha256Paths (sha1Paths ++ hashPaths);
      hashDupes = occuringIn hashPaths (sha1Paths ++ sha256Paths);
      noDupes =
        attr: ds: ds == [ ] || throw "${attr} has duplicate names ${toJSON ds}";
    };
    assert noDupes "sha1" sha1Dupes;
    assert noDupes "sha256" sha256Dupes;
    assert noDupes "hash" hashDupes;
    with {
      strings = filter (x: typeOf x == "string") [
        sha1
        sha256
        hash
      ];
    };
    assert
      length strings < 2
      || throw "Can't specify raw sha1/sha256/hash at same time; use sets";

    # Merge together all of the fetched results
    {
      inherit (deps) pkgs;
    }
    // recursiveUpdate (recursiveUpdate sha1s sha256s) hashes;

  # Wrap fetchAll in a way that allows overriding its dependencies
  makeFetcher = prevDeps: {
    __functor =
      _: args:
      with rec {
        # The fetcher we want, which uses all of the given overrides
        fetcher = makeFetcher deps;
        pick =
          name: fallback:
          if hasAttr name args then
            (_: getAttr name args)
          else
            (args.${fallback} or prevDeps.${fallback});
        deps = {
          gateways = args.gateways or prevDeps.gateways;
          mkPkgs = pick "pkgs" "mkPkgs";
          mkGoCar = pick "go-car" "mkGoCar";
        };

        # Fetch any hashes we've been given this time
        fetched = fetchAll args rec {
          # Plug together the overrides in various combinations, so our result
          # uses them all; but their definitions don't hit an infinite loop.
          inherit (deps) gateways;
          pkgs = deps.mkPkgs {
            fetchGitIPFS = makeFetcher {
              inherit (deps) gateways mkGoCar;
              inherit (prevDeps) mkPkgs;
            };
          };
          go-car = deps.mkGoCar {
            # Allow mkGoCar to use overridden pkgs
            pkgs = deps.mkPkgs {
              fetchGitIPFS = makeFetcher {
                inherit (deps) gateways;
                # Use previous versions of both to avoid loops
                inherit (prevDeps) mkGoCar mkPkgs;
              };
            };
            fetchGitIPFS = makeFetcher {
              inherit (deps) gateways mkPkgs;
              inherit (prevDeps) mkGoCar;
            };
          };
        };
        isDrv = (fetched.type or null) == "derivation";
      };
      rec {
        fetchGitIPFS = fetcher;
        ${if isDrv then null else "__functor"} = _: fetchGitIPFS;
      }
      // fetched;
  };

  fetchTreeFromGitHub =
    {
      owner,
      repo,
      tree,
    }:
    with {
      inherit (builtins)
        convertHash
        fetchurl
        hashFile
        path
        ;
      channelName = "${owner}-${repo}";
    };
    "${
      derivation {
        inherit channelName;
        name = "${owner}-${repo}-${tree}-unpacked";
        builder = "builtin:unpack-channel";
        system = "builtin";
        outputHashAlgo = "sha1";
        outputHashMode = "git";
        outputHash = convertHash {
          # The output of unpack-channel won't have tree as its SHA1 since it
          # will be wrapped in a directory (whose name matches channelName).
          # However, we can calculate the SHA1 of that wrapper, using tree and
          # channelName!
          hash = hashFile "sha1" (gitTreeSingleton {
            name = channelName;
            sha1 = tree;
          });
          hashAlgo = "sha1";
          toHashFormat = "sri";
        };
        src = fetchurl {
          name = "${owner}-${repo}-${tree}.tar.gz";
          url = "https://github.com/${owner}/${repo}/archive/${tree}.tar.gz";
        };
      }
    }/${channelName}";

  gitTreeSingleton =
    { name, sha1 }:

    with rec {
      inherit (builtins)
        concatStringsSep
        convertHash
        div
        toFile
        genList
        getAttr
        map
        stringLength
        substring
        toString
        ;
      rem = a: b: if a < b then a else rem (a - b) b;

      # Convert hex SHA1 string to binary bytes
      hexToBin =
        hex:
        with rec {
          pairCount = div (stringLength hex) 2;
          hexPairs = genList (i: substring (i * 2) 2 hex) pairCount;
          hexToDec =
            c:
            getAttr c {
              "0" = 0;
              "1" = 1;
              "2" = 2;
              "3" = 3;
              "4" = 4;
              "5" = 5;
              "6" = 6;
              "7" = 7;
              "8" = 8;
              "9" = 9;
              "a" = 10;
              "b" = 11;
              "c" = 12;
              "d" = 13;
              "e" = 14;
              "f" = 15;
            };
          pairToByte =
            pair:
            with {
              high = hexToDec (substring 0 1 pair);
              low = hexToDec (substring 1 1 pair);
            };
            high * 16 + low;
        };
        map pairToByte hexPairs;

      sha1Bytes = hexToBin (convertHash {
        hash = sha1;
        hashAlgo = "sha1";
        toHashFormat = "base16";
      });
      mode = "40000"; # For a subdirectory (tree), mode is "40000"

      # mode (5) + space (1) + name length + null (1) + sha1 (20)
      entryLen = 5 + 1 + (stringLength name) + 1 + 20;

      # Convert byte to octal for printf
      byteToOctal =
        byte:
        with rec {
          d1 = div byte 64;
          r1 = rem byte 64;
          d2 = div r1 8;
          d3 = rem r1 8;
        };
        "${toString d1}${toString d2}${toString d3}";

      builder = toFile "builder.sh" ''
        printf 'tree %s\x00' "${toString entryLen}" > "$out"

        # Write mode and space
        printf '%s' "${mode} " >> "$out"

        # Write name
        printf '%s' "${name}" >> "$out"

        # Write null byte after name
        printf '\x00' >> "$out"

        # Write SHA1 as binary bytes
        ${concatStringsSep "\n    " (
          map (byte: "printf '\\${byteToOctal byte}' >> \"$out\"") sha1Bytes
        )}
      '';

    };
    derivation {
      name = "git-tree-${name}";
      system = builtins.currentSystem;
      builder = "/bin/sh";
      args = [ builder ];
    };
};
makeFetcher {
  # Default arguments; if overridden, all subsequent fetchers will use those.
  gateways = [
    "http://127.0.0.1:8080" # Try default local gateway first, if available
    "https://ipfs.io"
    "https://dweb.link"
    "https://cloudflare-ipfs.com"
    "https://gateway.pinata.cloud"
    "https://ipfs.infura.io"
  ];

  mkGoCar =
    { pkgs, ... }:
    pkgs.go-car or (pkgs.buildGoModule {
      name = "go-car";
      modRoot = "cmd";
      subPackages = [ "car" ];
      vendorHash = "sha256-woC3y3F+JFwhHvEhWRecTRPzXAyElvORXefIjbOIpHE=";
      src = fetchTreeFromGitHub {
        owner = "ipld";
        repo = "go-car";
        tree = "7adb728aa46d3b04e17e5986b072353038e6e93f";
      };
    });

  mkPkgs =
    with {
      src = fetchTreeFromGitHub {
        owner = "nixos";
        repo = "nixpkgs";
        tree = "b40ca3074463ec424cc75c8d856dc37db12886f8";
      };
    };
    _:
    import src {
      config = { };
      overlays = [ ];
    };
}
