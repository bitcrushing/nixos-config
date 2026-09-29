# Forward the phone camera (over adb) to the v4l2loopback device.
# Usage: phone-cam [/dev/videoN] [extra scrcpy args]
# CAM_SIZE / CAM_FPS override the defaults. 640x480 loses nothing: the
# NeuralNet tracker downscales to ~224px anyway.

CAM_DEV="${1:-/dev/video10}"
[ "$#" -gt 0 ] && shift

echo "Forwarding phone camera to $CAM_DEV (Ctrl-C to stop)"
# The camera keeps capturing with the screen off; blank it to save heat and
# wake it again on exit (keyevent 223 = sleep, 224 = wake).
( sleep 3; adb shell input keyevent 223 ) &
trap 'adb shell input keyevent 224 2>/dev/null' EXIT
scrcpy --video-source=camera --no-audio --no-window \
  --camera-size="${CAM_SIZE:-640x480}" --camera-fps="${CAM_FPS:-60}" \
  --video-bit-rate=4M --v4l2-sink="$CAM_DEV" "$@"
