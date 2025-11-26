{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Codec.Archive.Tar as Tar
import qualified Codec.Archive.Tar.Entry as Tar
import Control.Exception (throw)
import Data.Aeson ((.:), (.=))
import qualified Data.Aeson as A
import qualified Data.Aeson.Encoding as A
import qualified Data.Aeson.Types as A
import qualified Data.ByteString.Lazy.Char8 as LB
import Data.List (isSuffixOf)
import Data.String (fromString)
import Data.String.Utils (join, split)

-- Pipe stdio through Tar.read/Tar.write, running fixEntry on each entry
main = LB.interact pipeTar
pipeTar = Tar.write . Tar.foldEntries fixEntry [] throw . Tar.read

-- Use these to abort the process if any error occurs
err = either error id
tarPath = err . Tar.toTarPath False

fixEntry x xs = case (Tar.entryContent x, path) of
    -- Keep NormalFiles, but change their path and possibly content
    (Tar.NormalFile f _, _ : n : v : _)
        | ".json" `isSuffixOf` last path ->
            fixFile n v f : xs
    -- Keep other files as-is, but drop the leading dir from their path
    (Tar.NormalFile _ _, _) ->
        x{Tar.entryTarPath = tarPath (join "/" (drop 1 path))} : xs
    -- Anything other than NormalFile gets dropped (directories, etc.)
    _ -> xs
  where
    path = split "/" (Tar.fromTarPath (Tar.entryTarPath x))

-- Parse JSON for source metadata, then use that to write a package.json
fixFile name version bytes = Tar.fileEntry path (A.encode pkg)
  where
    -- Replace all-cabal-hashes-xxx/p/v/p.json with p/v/package.json
    path = tarPath (name ++ "/" ++ version ++ "/package.json")
    location = concat ["<repo>/package/", name, "-", version, ".tar.gz"]
    existing = err (A.eitherDecode bytes)
    -- Parse required metadata from existing .json entry
    (size :: Int, md5 :: String, sha :: String) =
        err . ($ existing) . A.parseEither $ \obj -> do
            hashes <- obj .: "package-hashes"
            (,,)
                <$> obj .: "package-size"
                <*> hashes .: "MD5"
                <*> hashes .: "SHA256"
    -- Construct a new .json entry from the existing metadata
    pkg =
        A.object
            [ "signatures" .= ([] :: [Int])
            , "signed"
                .= A.object
                    [ "_type" .= ("Targets" :: String)
                    , "expires" .= A.Null
                    , "version" .= (0 :: Int)
                    , "targets"
                        .= A.object
                            [ fromString location
                                .= A.object
                                    [ "length" .= size
                                    , "hashes" .= A.object ["md5" .= md5, "sha256" .= sha]
                                    ]
                            ]
                    ]
            ]
