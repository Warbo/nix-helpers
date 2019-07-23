# Whether we should perform non-crucial checks that require being online. For
# example, looking up the latest version number of a package to see if we should
# warn about being out of date.
# Defaults to true; overridable by setting the env var to 0.
{}:
{
  def   = builtins.getEnv "NIX_ONLINE_CHECK" != "0";
  tests = {};
}
