{ hasBinary, withDeps }:

bin: pkg: withDeps [ (hasBinary pkg bin) ] pkg
