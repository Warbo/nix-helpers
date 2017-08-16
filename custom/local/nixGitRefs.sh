cache_git_rev_@key@() {
    nix_git_rev_@key@="@val@"
    export nix_git_rev_@key@
}

cache_git_rev_@key@

envHooks+=(cache_git_rev_@key@)
