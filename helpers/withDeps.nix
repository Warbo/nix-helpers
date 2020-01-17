# Add extra dependencies to a derivation; for example, if we only want a
# build to succeed if some external tests pass. To override the name too, use
# "withDeps'".

{ withDeps' }:

{
  def   = withDeps' null;
  tests = {};
}
