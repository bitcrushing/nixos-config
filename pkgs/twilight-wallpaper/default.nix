{
  lib,
  stdenv,
  pkg-config,
  wayland,
  wayland-scanner,
  wayland-protocols,
  wlr-protocols,
}:
stdenv.mkDerivation {
  pname = "twilight-wallpaper";
  version = "1.0";
  src = ./.;
  strictDeps = true;
  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];
  buildInputs = [ wayland ];
  buildPhase = ''
    runHook preBuild
    for spec in \
      ${wlr-protocols}/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml \
      ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml; do
      name=$(basename "$spec" .xml)
      wayland-scanner client-header "$spec" "$name.h"
      wayland-scanner private-code "$spec" "$name.c"
    done
    $CC -std=c11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
      main.c wlr-layer-shell-unstable-v1.c xdg-shell.c \
      $(pkg-config --cflags --libs wayland-client) -lm -o twilight-wallpaper
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 twilight-wallpaper $out/bin/twilight-wallpaper
    runHook postInstall
  '';
  meta = {
    description = "Damage-limited, low-rate Wayland twilight wallpaper";
    platforms = [ "x86_64-linux" ];
    mainProgram = "twilight-wallpaper";
    license = lib.licenses.mit;
  };
}
