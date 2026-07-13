{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./theme.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Stop numpad firmware from crashing
  boot.kernelParams = [ "usbhid.quirks=0x0c45:0x7018:0x00010000" ];
  boot.extraModprobeConfig = ''
    options usbhid quirks=0x0c45:0x7018:0x00010000
    options v4l2loopback devices=1 video_nr=10 card_label="PixelCam" exclusive_caps=1
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  # Wrap cosmic-comp with a custom fontconfig so window title bars use
  # VictorMono without affecting Firefox or other apps.
  nixpkgs.overlays = [
    (_final: prev: {
      cosmic-comp = prev.symlinkJoin {
        name = "cosmic-comp-wrapped";
        paths = [ prev.cosmic-comp ];
        buildInputs = [ prev.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/cosmic-comp \
            --set FONTCONFIG_FILE ${prev.writeText "cosmic-fontconfig.conf" ''
              <?xml version="1.0"?>
              <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
              <fontconfig>
                <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
                <match target="pattern">
                  <test name="family"><string>sans-serif</string></test>
                  <edit name="family" mode="prepend" binding="strong">
                    <string>VictorMono Nerd Font</string>
                  </edit>
                </match>
              </fontconfig>
            ''}
        '';
      };
    })
  ];

  networking.hostName = "PC"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Dublin";

  # COSMIC kept installed as a login fallback; the daily driver is now Niri.
  services.system76-scheduler.enable = true;
  services.xserver.enable = true; # XWayland for X11 apps under Niri
  services.desktopManager.cosmic.enable = true;
  programs.niri.enable = true;

  # Greetd login setup
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };
  # Let niri-session import the full user PATH (incl. home-manager bins)
  systemd.user.services.niri.enableDefaultPath = false;

  # Screen sharing, file picker
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Make COSMIC screenshots align when taking two screen-spanning screenshots
  environment.etc."cosmic-randr/monitors.kdl".text = ''
    output "HDMI-A-1" enabled=#true {
      description make="PNP(AOC)" model="2481W"
      position 0 0
      scale 1.00
      transform "normal"
      modes {
        mode 1920 1080 60000 current=#true preferred=#true
      }
    }
    output "HDMI-A-2" enabled=#true {
      description make="PNP(AOC)" model="2481W"
      position 1920 0
      scale 1.00
      transform "normal"
      modes {
        mode 1920 1080 60000 current=#true preferred=#true
      }
    }
  '';

  systemd.user.services.cosmic-randr-apply = {
    description = "Apply declarative COSMIC monitor layout";
    after = [ "cosmic-session.target" ];
    wantedBy = [ "cosmic-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "apply-cosmic-randr" ''
        export PATH="${
          lib.makeBinPath [
            pkgs.cosmic-randr
            pkgs.coreutils
          ]
        }:$PATH"
        for i in $(seq 1 30); do
          if cosmic-randr list >/dev/null 2>&1; then
            exec cosmic-randr kdl < /etc/cosmic-randr/monitors.kdl
          fi
          sleep 1
        done
        echo "cosmic-randr not available, could not apply monitor layout" >&2
        exit 1
      '';
    };
  };

  # Disable USB autosuspend for Focusrite Scarlett 6i6 & numpad to prevent dropouts
  services.udev.extraRules = ''
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8202", ATTR{power/control}="on"
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8203", ATTR{power/control}="on"
  '';

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # Enable low-latency audio via PipeWire.
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
        "default.clock.rate" = 44100;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
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
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "realtime"
    ];
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  hardware.steam-hardware.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  # Process scheduler optimisations (replaces GameMode)
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  security.sudo.extraConfig = ''
    Defaults env_editor
  '';

  # System-level extra packages
  environment.systemPackages = with pkgs; [
    wl-clipboard

    # Niri Wayland extensions
    waybar
    mako
    swaylock
    fuzzel
    swaybg
    libnotify

    # X11 apps under Niri
    xwayland-satellite
  ];

  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
    nerd-fonts.victor-mono
  ];

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
