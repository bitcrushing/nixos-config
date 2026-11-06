# OpenCE (Halo: Combat Evolved) — the project's official 32-bit Linux build.
#
# It is a prebuilt i686 executable that bundles SDL3, so it is packaged from
# the release zip instead of built. SDL3 loads X11/Wayland/OpenGL/audio at
# runtime, hence the launcher's LD_LIBRARY_PATH. The game writes config.toml
# and maps/ next to the executable, and its self-updater replaces the
# executable in place, which the store forbids; launcher.sh runs a copy in
# ~/.local/share/opence instead. The updater's binaries expect the FHS 32-bit
# loader, which modules/gaming/opence.nix provides. The pinned version is
# therefore only what a fresh install (or a package bump) starts from.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  coreutils,
  runtimeShell,
  alsa-lib,
  dbus,
  libdecor,
  libGL,
  libpulseaudio,
  libx11,
  libxcb,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
}:

let
  launcherTools = lib.makeBinPath [ coreutils ];

  # SDL3 discovers these with dlopen; they are not DT_NEEDED. They also go in
  # buildInputs so autoPatchelfHook finds them and writes their rpath.
  runtimeLibs = [
    alsa-lib
    dbus
    libdecor
    libGL
    libpulseaudio
    libx11
    libxcb
    libxcursor
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxscrnsaver
    pipewire
    systemd
    vulkan-loader
    wayland
  ];

  # Mesa's GL/EGL vendors come from /run/opengl-driver-32 (system-wide), so
  # only glvnd's dispatcher (libGL) is needed here.
  launcherLibs = lib.makeLibraryPath runtimeLibs;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "opence";
  version = "build-337";

  src = fetchurl {
    url = "https://github.com/OpenCommunityEdition/OpenCE/releases/download/${finalAttrs.version}/halo-linux-release.zip";
    hash = "sha256-esDq1uzmWY28AcPwu98yTv3Nc9oB2TQStZagPi4Vd7s=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/OpenCommunityEdition/OpenCE/${finalAttrs.version}/port/assets/icon/opence-icon.png";
    hash = "sha256-S/qATD2O6dOCzwXVRG0vxrAbQNKgR7G3bYl8lvmox00=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  # Only glibc/libgcc are linked; SDL3 dlopens everything else.
  buildInputs = runtimeLibs ++ [ stdenv.cc.cc.lib ];

  # SDL3's optional loaders that nixpkgs does not ship here (Steam API and
  # GLES; the game renders with desktop OpenGL).
  autoPatchelfIgnoreMissingDeps = [
    "libsteam_api.so"
    "libGLES_CM.so.1"
    "libGLESv1_CM.so.1"
    "libGLESv2.so.2"
  ];

  dontStrip = true;

  # Placeholders for substituteAll in launcher.sh.
  inherit launcherTools launcherLibs runtimeShell;

  unpackPhase = ''
    mkdir source
    unzip -q $src -d source
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/opence $out/bin
    cp -r source/. $out/share/opence
    # The release zip does not carry the execute bits.
    chmod +x $out/share/opence/halo $out/share/opence/halo-server

    substituteAll ${./launcher.sh} $out/bin/opence
    chmod +x $out/bin/opence

    install -Dm644 ${./opence.desktop} $out/share/applications/opence.desktop
    install -Dm644 $icon $out/share/icons/hicolor/512x512/apps/opence.png

    runHook postInstall
  '';

  meta = {
    description = "Open source port of Halo: Combat Evolved (32-bit release)";
    homepage = "https://github.com/OpenCommunityEdition/OpenCE";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "i686-linux"
    ];
    mainProgram = "opence";
    maintainers = [ ];
  };
})
