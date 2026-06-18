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

  # Stop numpad firmware from crashing
  boot.kernelParams = [ "usbhid.quirks=0x0c45:0x7018:0x00010000" ];
  boot.extraModprobeConfig = ''
    options usbhid quirks=0x0c45:0x7018:0x00010000
  '';

  systemd.services.numpad-numlock-fix = {
    description = "Hold NumLock ON for the Magicforce numpad (0c45:7018) to stop its firmware-reset loop";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 2;
      ExecStart = pkgs.writeShellScript "numpad-numlock-fix" ''
        # Tell the numpad (interface 0 = the boot-keyboard collection that owns the LED
       # output report) that NumLock is ON. hidraw output report layout for this device:
        #   byte0 = report id (0 = none),  byte1 = LED bitmap (bit0 = NumLock).
        while :; do
          active=0
          for d in /sys/class/hidraw/hidraw*; do
            [ -e "$d/device/uevent" ] || continue
            ue=$(< "$d/device/uevent")
            case "$ue" in *0003:00000C45:00007018*) ;; *) continue ;; esac
            ifn=$(< "$d/device/../bInterfaceNumber")
            [ "$ifn" = "00" ] || continue
            printf '\000\001' > "/dev/''${d##*/}" 2>/dev/null || true
            active=1
          done
          if [ "$active" = 1 ]; then sleep 0.25; else sleep 2; fi
        done
      '';
    };
  };
  # Force number input regardless of numlock state
  services.udev.extraHwdb = ''
    evdev:input:b0003v0C45p7018*
     KEYBOARD_KEY_70059=1
     KEYBOARD_KEY_7005a=2
     KEYBOARD_KEY_7005b=3
     KEYBOARD_KEY_7005c=4
     KEYBOARD_KEY_7005d=5
     KEYBOARD_KEY_7005e=6
     KEYBOARD_KEY_7005f=7
     KEYBOARD_KEY_70060=8
     KEYBOARD_KEY_70061=9
     KEYBOARD_KEY_70062=0
     KEYBOARD_KEY_70063=dot
     KEYBOARD_KEY_70053=reserved
   '';
   
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

  networking.hostName = "PC"; # Define your hostname.

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

  # Disable USB autosuspend for Focusrite Scarlett 6i6 & numpad to prevent dropouts
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
  };

  programs.firefox.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  security.sudo.extraConfig = ''
    Defaults env_editor
  '';

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to search for packages and options.
  environment.systemPackages = with pkgs; [
    # System-level audio utilities (tied to the PipeWire/JACK setup below).
    alsa-utils
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
