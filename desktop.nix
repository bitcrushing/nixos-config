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

  # Screen sharing + file pickers (Niri ships its own portal config)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # COSMIC used to enable these via mkDefault; keep them on explicitly.
  hardware.bluetooth.enable = true;
  services.avahi.enable = true; # mDNS — printer discovery for CUPS

  # Process scheduler optimisations (replaces GameMode)
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
