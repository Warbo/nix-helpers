{ callCabal2nixWithPlan }:
{
  can-build-json-to-msgpack =
    with {
      # Try to build some Haskell project; this one's nice and small
      src = fetchGit {
        url = "http://chriswarbo.net/git/json-to-msgpack.git";
        ref = "master";
        rev = "cc98560d2c4dae2f9d8ba5ea4e2966233a5d5327";
      };
    };
    callCabal2nixWithPlan {
      inherit src;
      name = "json-to-msgpack";
    };
}
