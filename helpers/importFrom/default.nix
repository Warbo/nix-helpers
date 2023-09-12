{ lib, nixFilesIn }: dir: lib.mapAttrs (_: import) (nixFilesIn dir)
