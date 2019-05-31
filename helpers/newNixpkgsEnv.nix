{}:
with builtins;
with {
  nixpkgs = with tryEval <nixpkgs>;
            if success then value else abort "Don't have <nixpkgs>?!";
};

{
  def = new: env: env // {
    NIX_PATH = "nixpkgs=${toString new}:real=${toString nixpkgs}";
  };

  tests = {};
}
