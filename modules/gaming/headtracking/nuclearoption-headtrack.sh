# Steam launch option for Nuclear Option: `nuclearoption-headtrack %command%`
# Starts the phone camera feed and opentrack, runs the game, then tears both
# down. Runs without `set -e` so teardown happens whatever the game returns.

CAM_DEV=/dev/video10

# 1. Phone camera -> v4l2loopback, if a phone is connected.
if ! pgrep -f "scrcpy.*v4l2-sink=$CAM_DEV" >/dev/null 2>&1; then
  if adb get-state >/dev/null 2>&1; then
    scrcpy --video-source=camera --no-audio --no-window \
      --camera-size="${CAM_SIZE:-640x480}" --camera-fps="${CAM_FPS:-60}" \
      --video-bit-rate=4M --v4l2-sink="$CAM_DEV" >/dev/null 2>&1 &
    CAM_PID=$!
    sleep 2
    adb shell input keyevent 223 2>/dev/null || true # screen off
  else
    echo "[nuclearoption-headtrack] no adb device; connect the phone or run 'phone-cam'" >&2
  fi
fi

# 2. opentrack (press Start in its window to begin tracking).
opentrack >/dev/null 2>&1 &
OT_PID=$!

# 3. The game. The launcher service lets opentrack-proton-wine run the Wine
#    bridge inside the game's container.
export STEAM_COMPAT_LAUNCHER_SERVICE=proton
"$@"
game_rc=$?

# 4. Teardown.
kill "$OT_PID" 2>/dev/null || true
if [ -n "${CAM_PID:-}" ]; then
  kill "$CAM_PID" 2>/dev/null || true
  adb shell input keyevent 224 2>/dev/null || true # screen on
fi
exit $game_rc
