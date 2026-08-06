# Gaming: Steam + the v4l2loopback virtual camera ("PixelCam").
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  hardware.steam-hardware.enable = true;

  # nix-ld provides a real dynamic linker shim at /lib64/ld-linux-x86-64.so.2
  # so that Proton's wine binary (which has that path hardcoded as its
  # interpreter) can run outside of bwrap/steam-run. This is critical for
  # opentrack's Wine output protocol: bwrap creates a private /dev/shm,
  # making the FT_SharedMem bridge invisible to the game. nix-ld doesn't
  # containerize, so both processes share the same /dev/shm.
  # We also create /lib/ld-linux.so.2 (32-bit loader) because Proton's wine
  # needs it even for 64-bit prefixes. nix-ld only covers 64-bit.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  };
  systemd.tmpfiles.rules = [
    "L /lib/ld-linux.so.2 - - - - ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2"
  ];

  # v4l2loopback virtual camera for headtracking
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="PixelCam" exclusive_caps=1
  '';

  # ─── Nuclear Option head tracking ────────────────────────────
  # Native Linux opentrack handles camera input (NeuralNet tracker sees
  # /dev/video10 directly via OpenCV/V4L2). The "Wine" output protocol
  # bridges head-pose data to the game's Proton prefix via shared memory
  # + a wrapper exe launched inside the prefix.
  #
  # The `opentrack-proton-wine` wrapper runs the bridge inside the game's
  # pressure-vessel container via Steam's compat launcher service so it
  # shares the game's wineserver (falls back to nix-ld outside the game).
  #
  # Phone camera -> scrcpy -> v4l2loopback (PixelCam /dev/video10) ->
  # native opentrack (NeuralNet) -> Wine bridge -> Nuclear Option.
  home-manager.users.bitcrushing =
    { pkgs, lib, ... }:
    {
      home.packages = [
        # Wrapper that opentrack uses as its "custom wine" binary.
        #
        # The game runs inside pressure-vessel which has a private /tmp
        # (and thus a private wineserver socket). The FT_SharedMem
        # mapping the wrapper exe creates is a wineserver-scoped named
        # object, so the wrapper's wine MUST connect to the *game's*
        # wineserver or the game never sees it. Unprivileged nsenter
        # into the container is not possible (setns needs CAP_SYS_ADMIN
        # in the owning userns), so we use Steam's supported mechanism:
        # the compat launcher service (STEAM_COMPAT_LAUNCHER_SERVICE=
        # proton, exported by nuclearoption-headtrack) exposes a D-Bus
        # name that steam-runtime-launch-client uses to run commands
        # inside the game's container with the full Proton environment
        # (correct PATH/WINEPREFIX/esync/fsync, shared wineserver).
        # OTR_WINE_PROTO is the only env var opentrack's shm handshake
        # needs forwarded; /dev/shm is shared with the host already.
        #
        # Fallback (game/service not running): run Proton's wine
        # directly via nix-ld so prefix maintenance still works.
        (pkgs.writeShellScriptBin "opentrack-proton-wine" ''
          APPID=2168680
          STEAM="''${STEAM_DIR:-$HOME/.local/share/Steam}"
          BUS="com.steampowered.App$APPID"

          # 1. Preferred: inject into the game's container via the
          #    compat launcher service.
          for rt in SteamLinuxRuntime_sniper SteamLinuxRuntime_4; do
            LC="$STEAM/steamapps/common/$rt/pressure-vessel/bin/steam-runtime-launch-client"
            [ -x "$LC" ] || continue
            if "$LC" --bus-name="$BUS" --list >/dev/null 2>&1; then
              # --directory: opentrack passes the NPClient DLL dir as a
              # path relative to ITS cwd; the wrapper registers it in the
              # prefix registry (NPClient Location). Without this the
              # command runs in the game dir and registers a bogus path.
              exec "$LC" --bus-name="$BUS" \
                --directory="$PWD" \
                --pass-env-matching='OTR_*' \
                -- wine "$@"
            fi
          done

          # 2. Fallback: run Proton's wine directly (own wineserver).
          #    Only useful when the game is NOT running (DLL/registry
          #    setup); the shm bridge won't reach a running game.
          PROTON_PATH=""
          if [ -f "$STEAM/steamapps/compatdata/$APPID/config_info" ]; then
            PROTON_NAME=$(head -1 "$STEAM/steamapps/compatdata/$APPID/config_info")
            for d in "$STEAM/compatibilitytools.d/$PROTON_NAME/files" "$STEAM/steamapps/common/$PROTON_NAME/files"; do
              [ -x "$d/bin/wine" ] && PROTON_PATH="$d" && break
            done
          fi
          [ -z "$PROTON_PATH" ] && PROTON_PATH="$STEAM/compatibilitytools.d/GE-Proton11-1/files"

          export NIX_LD="${pkgs.glibc}/lib64/ld-linux-x86-64.so.2"
          export NIX_LD_LIBRARY_PATH="$PROTON_PATH/lib:$PROTON_PATH/lib64:$PROTON_PATH/lib/wine/x86_64-unix:''${NIX_LD_LIBRARY_PATH:-}"
          exec "$PROTON_PATH/bin/wine" "$@"
        '')

        (pkgs.writeShellScriptBin "phone-cam" ''
          set -euo pipefail
          CAM_DEV="''${1:-/dev/video10}"
          [ "$#" -gt 0 ] && shift
          # Low latency: small frames + 60fps + modest bitrate. The
          # NeuralNet tracker downscales to ~224px internally, so
          # 640x480 loses nothing. Override via CAM_SIZE/CAM_FPS.
          # Thermals: camera capture keeps running with the screen off
          # (verified on Pixel/Android 16), so blank it while tracking
          # and wake it again on exit.
          echo "Forwarding phone camera to $CAM_DEV (Ctrl-C to stop)"
          ADB=${pkgs.android-tools}/bin/adb
          ( sleep 3; "$ADB" shell input keyevent 223 ) &
          trap '"$ADB" shell input keyevent 224 2>/dev/null' EXIT
          ${pkgs.scrcpy}/bin/scrcpy --video-source=camera --no-audio --no-window \
            --camera-size="''${CAM_SIZE:-640x480}" --camera-fps="''${CAM_FPS:-60}" \
            --video-bit-rate=4M --v4l2-sink="$CAM_DEV" "$@"
        '')

        # Steam launch option: `nuclearoption-headtrack %command%`
        # Starts the camera feed + native opentrack, then launches the game.
        (pkgs.writeShellScriptBin "nuclearoption-headtrack" ''
          set -uo pipefail
          CAM_DEV=/dev/video10

          # 1. Feed phone camera -> v4l2loopback if a device is connected
          if ! pgrep -f "scrcpy.*v4l2-sink=$CAM_DEV" >/dev/null 2>&1; then
            if ${pkgs.android-tools}/bin/adb get-state >/dev/null 2>&1; then
              ${pkgs.scrcpy}/bin/scrcpy --video-source=camera --no-audio --no-window \
                --camera-size="''${CAM_SIZE:-640x480}" --camera-fps="''${CAM_FPS:-60}" \
                --video-bit-rate=4M --v4l2-sink="$CAM_DEV" >/dev/null 2>&1 &
              CAM_PID=$!
              sleep 2
              # Blank the phone screen while tracking (saves power/heat;
              # camera capture continues with screen off)
              ${pkgs.android-tools}/bin/adb shell input keyevent 223 2>/dev/null || true
            else
              echo "[nuclearoption-headtrack] no adb device; connect phone or run 'phone-cam' manually" >&2
            fi
          fi

          # 2. Start native opentrack (user clicks Start to begin tracking)
          ${pkgs.opentrack}/bin/opentrack >/dev/null 2>&1 &
          OT_PID=$!

          # 3. Launch the game (Steam substitutes %command% with the Proton line).
          #    The launcher service lets opentrack-proton-wine inject the
          #    Wine bridge into the game's container (shared wineserver).
          export STEAM_COMPAT_LAUNCHER_SERVICE=proton
          "$@"
          game_rc=$?

          # 4. Tear down (wake the phone screen back up)
          kill "$OT_PID" 2>/dev/null || true
          if [ -n "''${CAM_PID:-}" ]; then
            kill "$CAM_PID" 2>/dev/null || true
            ${pkgs.android-tools}/bin/adb shell input keyevent 224 2>/dev/null || true
          fi
          exit $game_rc
        '')
      ];

      # Ensure opentrack's Wine output protocol is configured to use the
      # wine64 wrapper as its custom wine binary, pointing at Nuclear
      # Option's Proton prefix. Also copies the NPClient/FreeTrack DLLs
      # into the prefix so the game can read the shared-memory bridge.
      # Self-heals on every activation.
      home.activation.opentrackWineConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CFG="$HOME/.config/opentrack-2.3/default.ini"
        [ -f "$CFG" ] || exit 0
        $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i \
          -e 's|^protocol-dll=.*|protocol-dll=wine|' \
          -e '/^\[proto-wine\]/,/^\[/ {
            s|^protocol=.*|protocol=2|
            s|^variant-wine=.*|variant-wine=true|
            s|^variant-proton=.*|variant-proton=false|
            s|^variant-proton-external=.*|variant-proton-external=false|
            s|^variant-proton-steamplay=.*|variant-proton-steamplay=false|
            s|^wine-select-version=.*|wine-select-version=CUSTOM|
            s|^wine-custom-version=.*|wine-custom-version=/etc/profiles/per-user/bitcrushing/bin/opentrack-proton-wine|
            s|^wineprefix=.*|wineprefix=/home/bitcrushing/.local/share/Steam/steamapps/compatdata/2168680/pfx/|
          }' "$CFG"

        # Copy NPClient + FreeTrack DLLs into the prefix so the game can
        # read the opentrack shared-memory bridge.
        PFX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx/drive_c"
        [ -d "$PFX" ] || exit 0
        OTLIB="${pkgs.opentrack}/libexec/opentrack"
        for dll in NPClient64.dll freetrackclient64.dll NPClient.dll freetrackclient.dll; do
          if [ -f "$OTLIB/$dll" ] && [ ! -f "$PFX/windows/system32/$dll" ]; then
            $DRY_RUN_CMD cp -L "$OTLIB/$dll" "$PFX/windows/system32/$dll"
          fi
        done
        for dll in NPClient.dll freetrackclient.dll; do
          if [ -f "$OTLIB/$dll" ] && [ ! -f "$PFX/windows/syswow64/$dll" ]; then
            $DRY_RUN_CMD cp -L "$OTLIB/$dll" "$PFX/windows/syswow64/$dll"
          fi
        done
      '';
    };
}
