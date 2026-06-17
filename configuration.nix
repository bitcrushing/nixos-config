# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "bcachefs" ];

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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "nixPC"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Dublin";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  services.system76-scheduler.enable = true;
  services.xserver.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Disable USB autosuspend for Focusrite Scarlett 6i6 to prevent dropouts
  services.udev.extraRules = ''
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8202", ATTR{power/control}="on"
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8203", ATTR{power/control}="on"
  '';

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # Enable low-latency professional audio via PipeWire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire."10-lowlatency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 512;
      };
    };
  };
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/main.lua.d/99-scarlett-profile.lua" ''
      rule = {
        matches = {
          {
            { "device.name", "matches", "alsa_card.usb-Focusrite_Scarlett_6i6_USB_00023256-00" },
          },
        },
        apply_properties = {
          ["device.profile"] = "output:analog-surround-50",
        },
      }
    '')
  ];

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.bitcrushing = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "realtime" ]; # Enable 'sudo' for the user.
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to search for packages and options.
  environment.systemPackages = with pkgs; [
    helix
    wget
    git
    p7zip
    opencode
    ghostty
    discord
    mpv
    syncplay
    libreoffice
    fastfetch
    btop
    qbittorrent
    obs-studio
    lutris
    bottles
    protonup-qt
    qpwgraph
    alsa-utils
    qjackctl
    pavucontrol
    spotify-player
  ];

  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # configured in a following section.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you have upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your OS is pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
