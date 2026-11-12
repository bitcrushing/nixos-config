# Host entry point. This file is the table of contents: every module is
# listed explicitly (there is no auto-import) and settings live in modules/.
# Only the state versions stay here because they belong to the host itself.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    # System
    ./modules/system/boot.nix
    ./modules/system/base.nix
    ./modules/system/nix.nix
    ./modules/system/storage.nix
    ./modules/system/tailscale.nix

    # Look and terminal
    ./modules/theme.nix
    ./modules/shell/bash.nix
    ./modules/shell/cli.nix
    ./modules/shell/ghostty.nix

    # Desktop
    ./modules/apps/default.nix
    ./modules/apps/filebrowser.nix
    ./modules/apps/qbittorrent.nix
    ./modules/apps/vesktop.nix
    ./modules/desktop/niri.nix
    ./modules/desktop/noctalia.nix
    ./modules/desktop/wayvnc.nix
    ./modules/desktop/wallpaper.nix
    ./modules/desktop/portals.nix
    ./modules/desktop/screenshots.nix

    # Hardware
    ./modules/hardware/bluetooth.nix
    ./modules/hardware/numpad.nix
    ./modules/hardware/drawing-keypad.nix
    ./modules/hardware/peripherals.nix
    ./modules/hardware/printing.nix

    # Audio
    ./modules/audio/pipewire.nix
    ./modules/audio/production.nix

    # Gaming
    ./modules/gaming/compat.nix
    ./modules/gaming/steam.nix
    ./modules/gaming/opence.nix
    ./modules/gaming/headtracking.nix

    # Editors and tools
    ./modules/editors/neovim.nix
    ./modules/editors/tooling.nix
    ./modules/pi/default.nix
  ];

  # Never change these after install; they are not the NixOS version.
  system.stateVersion = "26.05";
  hm.home.stateVersion = "26.05";
}
