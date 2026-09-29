# Host-wide basics. Everything else lives in a topic module under modules/;
# the imports list below is the table of contents.
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./modules/theme.nix # stylix: colours, fonts, cursor, icons, wallpaper
    ./modules/shell.nix # bash, CLI tools, git, ghostty
    ./modules/apps.nix # GUI apps without their own module
    ./modules/storage.nix # /mnt/data + weekly bcachefs scrub

    ./modules/desktop/niri.nix # compositor, login, session services
    ./modules/desktop/waybar.nix
    ./modules/desktop/wallpaper.nix # generated from the palette, one image across both monitors
    ./modules/desktop/portals.nix # screencast / file picker routing
    ./modules/desktop/tools.nix # idle lock, volume OSD, clipboard history, screenshot annotation, power menu

    ./modules/hardware/bluetooth.nix
    ./modules/hardware/numpad.nix # Magicforce numpad NumLock workaround
    ./modules/hardware/peripherals.nix # Razer mouse, input-remapper
    ./modules/hardware/printing.nix

    ./modules/audio/pipewire.nix # low-latency PipeWire, Scarlett 6i6
    ./modules/audio/production.nix # DAWs, plugins, PipeASIO

    ./modules/gaming/steam.nix
    ./modules/gaming/headtracking.nix # opentrack + phone camera for Nuclear Option

    ./modules/editors/neovim.nix
    ./modules/editors/tooling.nix # LSPs, formatters, dev tools

    ./modules/pi # pi coding agent
  ];

  nixpkgs.overlays = [ (import ./pkgs) ];
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true; # hard-link identical files in the store

  # Housekeeping: weekly, keep the 5 newest system generations and delete
  # everything no longer referenced. The boot menu lists at most 5.
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  systemd.services.nix-gc.preStart = "${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +5";

  # ─── Boot ───────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.cleanOnBoot = true; # /tmp is on the root disk, so it would otherwise never empty

  # ─── System ─────────────────────────────────────────────────
  networking.hostName = "PC";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Dublin";

  users.users.bitcrushing = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
    ];
  };

  security.sudo.extraConfig = ''
    Defaults env_editor
  '';

  # Process priority rules (CachyOS ruleset).
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # Never change these after install; they are not the NixOS version.
  system.stateVersion = "26.05";
  hm.home.stateVersion = "26.05";
}
