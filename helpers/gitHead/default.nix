_:

{
  url,
  ref ? "HEAD",
  ...
}:
(builtins.fetchGit { inherit url ref; }).rev
