{ callCabal2nixWithPlan }:
{
  can-build-json-to-msgpack =
    with {
      # Try to build some Haskell project; this one's nice and small
      src = fetchGit {
        url = "http://chriswarbo.net/git/json-to-msgpack.git";
        ref = "master";
        rev = "07bf1f3ddc7c46fae7095ec8e496defc357882ce";
      };
    };
    callCabal2nixWithPlan {
      inherit src;
      name = "json-to-msgpack";
    };
}
