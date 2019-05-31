{}:

with builtins;
with rec {
  go = lst: if lst == []
               then []
               else go (tail lst) ++ [(head lst)];
};

{
  def   = go;
  tests = {};
}
