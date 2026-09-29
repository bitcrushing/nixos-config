# Run on every home-manager activation. Points opentrack's Wine output at
# opentrack-proton-wine and Nuclear Option's prefix, and copies the
# NPClient/FreeTrack DLLs into the prefix. Does nothing until opentrack and
# the game have each been run once.

APPID=2168680
CFG="$HOME/.config/opentrack-2.3/default.ini"
PFX="$HOME/.local/share/Steam/steamapps/compatdata/$APPID/pfx"

if [ -f "$CFG" ]; then
  sed -i \
    -e 's|^protocol-dll=.*|protocol-dll=wine|' \
    -e '/^\[proto-wine\]/,/^\[/ {
      s|^protocol=.*|protocol=2|
      s|^variant-wine=.*|variant-wine=true|
      s|^variant-proton=.*|variant-proton=false|
      s|^variant-proton-external=.*|variant-proton-external=false|
      s|^variant-proton-steamplay=.*|variant-proton-steamplay=false|
      s|^wine-select-version=.*|wine-select-version=CUSTOM|
      s|^wine-custom-version=.*|wine-custom-version='"$OPENTRACK_WINE"'|
      s|^wineprefix=.*|wineprefix='"$PFX"'/|
    }' "$CFG"
fi

if [ -d "$PFX/drive_c" ]; then
  WIN="$PFX/drive_c/windows"
  for dll in NPClient64.dll freetrackclient64.dll NPClient.dll freetrackclient.dll; do
    if [ -f "$OPENTRACK_LIB/$dll" ] && [ ! -f "$WIN/system32/$dll" ]; then
      cp -L "$OPENTRACK_LIB/$dll" "$WIN/system32/$dll"
    fi
  done
  for dll in NPClient.dll freetrackclient.dll; do
    if [ -f "$OPENTRACK_LIB/$dll" ] && [ ! -f "$WIN/syswow64/$dll" ]; then
      cp -L "$OPENTRACK_LIB/$dll" "$WIN/syswow64/$dll"
    fi
  done
fi
