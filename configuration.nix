{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./audio.nix
    ./desktop.nix
    ./gaming.nix
    ./printing.nix
    ./theme.nix
    ./niri.nix
  ];

  # ─── Boot ───────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "bcachefs" ];

  # ─── Filesystems ────────────────────────────────────────────
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "bcachefs";
  };

  systemd.services.bcachefs-scrub = {
    description = "bcachefs scrub";
    serviceConfig.ExecStart = "${pkgs.bcachefs-tools}/bin/bcachefs fsck -n /dev/nvme0n1p1";
  };

  systemd.timers.bcachefs-scrub = {
    wantedBy = [ "timers.target" ];
    timerConfig.onCalendar = "weekly";
  };

  # ─── Nix ────────────────────────────────────────────────────
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # ─── Networking ─────────────────────────────────────────────
  networking.hostName = "PC";
  networking.networkmanager.enable = true;

  # ─── Time ───────────────────────────────────────────────────
  time.timeZone = "Europe/Dublin";

  # ─── User ───────────────────────────────────────────────────
  users.users.bitcrushing = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "realtime"
    ];
  };

  # ─── Misc ───────────────────────────────────────────────────
  security.sudo.extraConfig = ''
    Defaults env_editor
  '';

  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
    nerd-fonts.victor-mono
  ];

  # This option defines the first version of NixOS you have installed on this
  # particular machine, and is used to maintain compatibility with application
  # data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any
  # reason, even if you have upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your OS is pulled from, so
  # changing it will NOT upgrade your system - see
  # https://nixos.org/manual/nixos/stable/#sec-upgrading for how to actually do that.
  #
  # Do NOT change this value unless you have manually inspected the changes it
  # would make to your configuration, and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or
  # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05";
}
