{ lib, makeWrapper, python, runCommand, withArgsOf, withDeps, writeScript }:

with builtins;
with lib;
with rec {
  # Try a bunch of strings with quotes, spaces, etc. and see if they survive
  checks = mapAttrs (n: v: runCommand "wrap-escapes-${n}"
                             {
                               cmd = wrap rec {
                                 vars   = { "${n}" = v; };
                                 name   = "check-wrap-escaping-${n}";
                                 paths  = [ python ];
                                 script = ''
                                   #!/usr/bin/env python
                                   from os import getenv

                                   n   = '${n}'
                                   v   = """${v}"""
                                   msg = "'{0}' was '{1}' not '{2}'"
                                   env = getenv(n)

                                   assert env == v, msg.format(n, env, v)

                                   print 'true'
                                 '';
                               };
                             }
                             ''"$cmd" > "$out"'')
                    {
                      SIMPLE = "simple";
                      SPACES = "with some spaces";
                      SINGLE = "withA'Quote";
                      DOUBLE = ''withA"Quote'';
                      MEDLEY = ''with" all 'of the" above'';
                    };

  # makeWrapper has some horrible quoting issues. In particular:
  #  - Values are spliced into the resulting script as-is, i.e. without any
  #    escaping. Hence we need to escape them ourselves.
  #  - Escaping in bash is done by wrapping in single quotes and replacing any
  #    single quotes in the string with '\'' (the first ' closes the first part
  #    of the string, the following \' is the literal quote that we want (in
  #    bash, juxtaposition is string concatenation), then we begin the rest of
  #    the string using the final '.
  #  - Since makeWrapper is a bash function, we have to call it from bash, and
  #    that requires escaping our values again (the call to makeWrapper will
  #    strip off one layer of escaping; the second layer will be stripped off
  #    when the parsing script is being parsed).
  #  - Values (but not names) automatically get wrapped in "double quotes"; this
  #    messes up our escaping: one the one hand, it causes our single quotes to
  #    all appear as literals, which we don't want; on the other hand, it causes
  #    many potential inputs (e.g. things containing $) to be mangled, which is
  #    precisely what we wanted to avoid!
  #  - To avoid these double quotes, we surround our double-escaped string with
  #    double quotes; hence 'foo' becomes "'foo'", which when wrapped in double
  #    quotes becomes ""'foo'"", which bash will parse as three strings: an
  #    empty string "", a string 'foo' and an empty string "". Concatenating
  #    these is equivalent to the 'foo' that we wanted.
  #  - Pro tip to any readers: try to avoid unintended string interpretation
  #    wherever you can. Instead of "quoting variables where necessary", you
  #    should always quote all variables; instead of embedding raw strings into
  #    generated scripts and sprinkling around some quote marks, you should
  #    always escape them properly (replace single quotes with '\'' and wrap in
  #    single quotes); never treat double quotes as an escaping mechanism.
  set = n: v:
    with rec {
      en =          escapeShellArg (escapeShellArg n);
      ev = "'\"'" + escapeShellArg (escapeShellArg v) + "'\"'";
    };
    "--set ${en} ${ev}";

  wrap = { paths ? [], vars ? {}, file ? null, script ? null, name ? "wrap" }:
    assert file != null || script != null ||
           abort "wrap needs 'file' or 'script' argument";
    with rec {
      f    = if file == null then writeScript name script else file;
      args = (map (p: "--prefix PATH : ${p}/bin") paths) ++
             (attrValues (mapAttrs set vars));
    };
    runCommand name
      {
        inherit f;
        buildInputs = [ makeWrapper ];
      }
      ''
        makeWrapper "$f" "$out" ${concatStringsSep " " args}
      '';
};

args: withDeps (attrValues checks) (wrap args)
