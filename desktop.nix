# Niri Wayland session: compositor, login, portals, and session helpers.
{ pkgs, ... }:

{
  services.xserver.enable = true; # XWayland for X11 apps under Niri
  programs.niri.enable = true;

  # Lightweight greetd + tuigreet login prompt.
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

  # Screen sharing + file pickers. Niri prefers the GNOME portal
  # (https://github.com/niri-wm/niri/discussions/3554), but Discord's 2026-03
  # Vulkan capture can't import niri's DMA-BUF-only stream (niri#4178,
  # niri#1791), so route ScreenCast through the wlr portal instead.
  #
  # NOTE: this must go in config.niri (-> /etc/xdg-desktop-portal/
  # niri-portals.conf). The generic config.common/portals.conf is overridden
  # by niri's shipped niri-portals.conf and silently has no effect (niri#3821).
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-wlr
    ];
    # Mirrors niri's shipped niri-portals.conf, with ScreenCast overridden.
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = "gtk";
      "org.freedesktop.impl.portal.Notification" = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      "org.freedesktop.impl.portal.ScreenCast" = "wlr";
    };
  };

  # COSMIC used to enable these via mkDefault; keep them on explicitly.
  hardware.bluetooth.enable = true;

  # The DualSense pairs but does not establish a classic BR/EDR bond, and
  # BlueZ's input profile rejects non-bonded HID connections by default
  # (journal: "hidp_add_connection() Rejected connection from !bonded device"),
  # so the kernel HID/gamepad device is never created. Allow non-bonded HID.
  hardware.bluetooth.input.General.ClassicBondedOnly = false;

  # Keep the adapter pairable. If it isn't, BlueZ completes DualSense pairing
  # but never stores the link key (info file ends up with no [LinkKey]), so the
  # pad shows "Bonded: no" and cannot re-authenticate after a reboot. Forcing
  # AlwaysPairable ensures a real bond is persisted.
  hardware.bluetooth.settings.General.AlwaysPairable = true;

  # Guarantee the DualSense driver is present early at boot; the bluez bug
  # threads show reconnect failing when hid_playstation isn't loaded in time.
  boot.kernelModules = [ "hid_playstation" ];
  services.avahi.enable = true; # mDNS — printer discovery for CUPS

  # Process scheduler optimisations
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard

    # Niri session helpers (bar, notifications, launcher, lock, wallpaper)
    waybar
    mako
    swaylock
    fuzzel
    swaybg
    libnotify

    # X11 apps under Niri (auto-started by Niri when on PATH)
    xwayland-satellite
  ];
}
