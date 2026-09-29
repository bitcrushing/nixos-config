# opentrack's "custom wine" binary for Nuclear Option (Steam app 2168680).
#
# The shared-memory object opentrack's bridge creates is scoped to a
# wineserver, so the bridge must run under the *game's* wineserver, inside
# its pressure-vessel container. Unprivileged nsenter can't enter it, so use
# Steam's compat launcher service (enabled by nuclearoption-headtrack via
# STEAM_COMPAT_LAUNCHER_SERVICE=proton), which runs commands in the
# container with the game's full Proton environment.

APPID=2168680
STEAM="${STEAM_DIR:-$HOME/.local/share/Steam}"
BUS="com.steampowered.App$APPID"

# 1. Game running: run wine inside its container.
for rt in SteamLinuxRuntime_sniper SteamLinuxRuntime_4; do
  LC="$STEAM/steamapps/common/$rt/pressure-vessel/bin/steam-runtime-launch-client"
  [ -x "$LC" ] || continue
  if "$LC" --bus-name="$BUS" --list >/dev/null 2>&1; then
    # opentrack passes the NPClient DLL dir relative to its own cwd, so keep
    # the cwd or the prefix registry gets a bogus "NPClient Location".
    # OTR_* is the only environment the shm handshake needs.
    exec "$LC" --bus-name="$BUS" \
      --directory="$PWD" \
      --pass-env-matching='OTR_*' \
      -- wine "$@"
  fi
done

# 2. Game not running: run the game's Proton wine directly through nix-ld
#    (own wineserver). Only useful for prefix setup (DLLs, registry).
#    Line 2 of config_info is "<proton>/files/share/fonts/".
CONFIG_INFO="$STEAM/steamapps/compatdata/$APPID/config_info"
PROTON_PATH=""
if [ -f "$CONFIG_INFO" ]; then
  PROTON_PATH=$(sed -n '2s|/share/fonts/*$||p' "$CONFIG_INFO")
fi
if [ ! -x "$PROTON_PATH/bin/wine" ]; then
  echo "opentrack-proton-wine: can't find Proton for app $APPID (launch the game once)" >&2
  exit 1
fi

export NIX_LD="$NIX_LD_LOADER"
export NIX_LD_LIBRARY_PATH="$PROTON_PATH/lib:$PROTON_PATH/lib64:$PROTON_PATH/lib/wine/x86_64-unix:${NIX_LD_LIBRARY_PATH:-}"
exec "$PROTON_PATH/bin/wine" "$@"
