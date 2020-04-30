# xvfb-run has a few annoyances. Most important are that, prior to the end of
# 2017, it redirects stderr to stdout; it also clobbers itself if multiple
# instances are run. We fix this, as well as providing niceties like VNC access.
{ bash, fail, mkBin, replace, runCommand, utillinux, x11vnc, xvfb_run }:

with rec {
  # Hack to avoid unwanted quasiquotes
  braced = s: "$" + "{" + s + "}";

  # Patch xvfb_run to stop it merging stderr into stdout
  patched = runCommand "patch-xvfb-run"
    {
      buildInputs = [ fail replace ];
      old         = xvfb_run;
      broken      = ''DISPLAY=:$SERVERNUM XAUTHORITY=$AUTHFILE "$@" 2>&1'';
      fixed       = ''
        [[ -z "$DEBUG" ]] || set -x
        VNCPID=""
        if [[ "x$XVFB_VNC" = "x1" ]]
        then
          echo "Starting VNC server, as requested" 1>&2
          DISPLAY=":$SERVERNUM" XAUTHORITY="$AUTHFILE" x11vnc -localhost \
                                                              -quiet 1>&2 &
          VNCPID="$!"
        fi
        DISPLAY=":$SERVERNUM" XAUTHORITY="$AUTHFILE" "$@"
        [[ -z "$VNCPID" ]] || kill "$VNCPID"
      '';
    }
    ''
      set -e

      cp -rv "$old" "$out"
      chmod +w -R "$out"

      # Update references, e.g. in makeWrapper scripts
      find "$out" -type f | while read -r FILE
      do
        replace "$old" "$out" -- "$FILE"
      done

      # Look for the script. If it's been through makeWrapper, use the original.
         NAME="xvfb-run"
      WRAPPED="$out/bin/.${braced "NAME"}-wrapped"
       SCRIPT="$out/bin/$NAME"

      if [[ -f "$WRAPPED" ]]
      then
        SCRIPT="$WRAPPED"
      fi

      [[ -f "$SCRIPT" ]] || fail "xvfb-run script '$SCRIPT' not found"

      if grep -F "$broken" < "$SCRIPT"
      then
        echo "Patching broken xvfb-run script" 1>&2
        replace "$broken" "$fixed" -- "$SCRIPT"
      else
        echo "Not patching '$SCRIPT' since it doesn't appear broken" 1>&2
      fi
    '';

  # Wrap xvfb_run, so we can find a free DISPLAY number, etc.
  go = mkBin {
    name   = "xvfb-run-safe";
    paths  = [ bash fail utillinux patched x11vnc ];
    script = ''
      #!${bash}/bin/bash
      set -e
      [[ -z "$DEBUG" ]] || set -x

      # allow settings to be updated via environment
      # shellcheck disable=SC2154
      : "${braced "xvfb_lockdir:=/tmp/xvfb-locks"}"

      # shellcheck disable=SC2154
      : "${braced "xvfb_display_min:=99"}"

      # shellcheck disable=SC2154
      : "${braced "xvfb_display_max:=599"}"

      mkdir -p -- "$xvfb_lockdir" ||
        fail "Couldn't make xvfb_lockdir '$xvfb_lockdir'"

      chmod a+w "$xvfb_lockdir" 2> /dev/null || true

      PERMISSIONS=$(stat -L -c "%a" "$xvfb_lockdir")
            OCTAL="0$PERMISSIONS"
         WRITABLE=$(( OCTAL & 0002 ))

      function debugMsg {
        [[ -z "$DEBUG" ]] || echo -e "$*" 1>&2
      }

      if [[ "$WRITABLE" -ne 2 ]]
      then
        echo "ERROR: xvfb_lockdir '$xvfb_lockdir' isn't world writable" 1>&2
        fail "This may cause users to clobber each others' DISPLAY"     1>&2
      fi

      function cleanUp {
        # Gracefully stop 'tail' command
        [[ -z "$ERRPID" ]] || {
          # Fire off a bg job which waits, then kills tail (if still running)
          (sleep 1; kill "$ERRPID" 2> /dev/null || true;) &

          # Wait for tail to die by making it an fg job (if still running)
          fg 2> /dev/null || true
        }
        for F in "$xvfb_lockdir/$i" "/tmp/.X$i-lock" "/tmp/.X11-unix/X$i" \
                 "$xvfb_lockdir/$i.err"
        do
          rm -f "$F" || debugMsg "Failed to delete '$F'. Oh well."
        done
      }
      trap cleanUp EXIT

      # Look for a free DISPLAY number, starting from min and going to max
      ERRPID=""
      for i in $(seq "$xvfb_display_min" "$xvfb_display_max" | shuf)
      do
        if [[ -e "/tmp/.X$i-lock" ]]
        then
          debugMsg "Skipping X display on :$i"
          (( ++i ))
          continue
        fi

        if [[ -e "/tmp/.X11-unix/X$i" ]]
        then
          debugMsg "Skipping existing socket '/tmp/.X11-unix/X$i'"
          (( ++i ))
          continue
        fi

        if [[ -e "$xvfb_lockdir/$i" ]]
        then
          debugMsg "Skipping existing lock file '$xvfb_lockdir/$i'"
          (( ++i ))
          continue
        fi

        exec 5> "$xvfb_lockdir/$i" || {
          debugMsg "Couldn't lock '$xvfb_lockdir/$i', skipping"
          (( ++i ))
          continue
        }

        # Wait for the lock
        if flock -x -n 5
        then
          debugMsg "Aquired lock '$xvfb_lockdir/$i', running command"

          # Stream stderr (process substitution doesn't seem to work)
          touch "$xvfb_lockdir/$i.err"
          if [[ -n "$DEBUG" ]]
          then
            tail -f "$xvfb_lockdir/$i.err" >&2 &
            ERRPID="$!"
          fi

          xvfb-run --server-num="$i" -e "$xvfb_lockdir/$i.err" "$@"
          RET="$?"

          # Break the loop now that we've finished
          exit "$RET"
        fi

        # If we couldn't get the lock (e.g. due to a timeout), try the next
        (( ++i ))
      done
    '';
  };
};

{
  def   = go;
  tests = {};
}
