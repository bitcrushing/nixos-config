# xdg-desktop-portal routing. The niri module already configures the
# GNOME/GTK portals; this only moves ScreenCast to the wlr portal.
{ pkgs, ... }:

{
  # ScreenCast goes through xdg-desktop-portal-wlr because the official
  # Discord client's Vulkan capture couldn't import the GNOME portal's
  # DMA-BUF-only stream (niri#4178, niri#1791). Discord is now Vesktop
  # (WebRTC capture); if screen sharing in Vesktop and OBS works without this
  # line, this module can go.
  #
  # Must be set in config.niri: niri ships its own niri-portals.conf, which
  # takes precedence over config.common (niri#3821).
  xdg.portal.config.niri."org.freedesktop.impl.portal.ScreenCast" = "wlr";

  xdg.portal.extraPortals = [
    # xdpw 0.8.5 already contains the wlr-screencopy stall fixes
    # (xdpw#390, #395), so no local patches are needed.
    pkgs.xdg-desktop-portal-wlr
  ];
}
