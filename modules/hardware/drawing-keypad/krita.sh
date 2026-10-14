# `krita` wrapper (overlay in ../drawing-keypad.nix): starts the drawing
# keypad while Krita runs and stops it when the last Krita launch exits.
# Krita is single-instance, so a second launch hands its files to the first
# and exits at once; the shared lock keeps that from stopping the keypad.

lock="${XDG_RUNTIME_DIR:-/tmp}/krita-keypad.lock"
exec {fd}>"$lock"
flock --shared "$fd"

# --no-block: kanata waits ~2 s before grabbing; don't hold Krita up for it.
systemctl start --no-block kanata-drawing.service ||
  echo "krita: couldn't start kanata-drawing.service" >&2

status=0
"$KRITA" "$@" || status=$?

# Exclusive only succeeds when no other launch still holds the lock.
if flock --exclusive --nonblock "$fd"; then
  systemctl stop --no-block kanata-drawing.service || true
fi
exit "$status"
