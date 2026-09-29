# xdg-desktop-portal routing. The niri module already configures the
# GNOME/GTK portals; this only moves ScreenCast to the wlr portal.
{ pkgs, ... }:

{
  # ScreenCast goes through xdg-desktop-portal-wlr because the official
  # Discord client's Vulkan capture couldn't import the GNOME portal's
  # DMA-BUF-only stream (niri#4178, niri#1791). Discord has since been
  # replaced by Vesktop (WebRTC capture), which may work with niri's default
  # GNOME portal. If screen sharing in Vesktop and OBS works without this
  # line, drop it and the xdpw patches below.
  #
  # Must be set in config.niri: niri ships its own niri-portals.conf, which
  # takes precedence over config.common (niri#3821).
  xdg.portal.config.niri."org.freedesktop.impl.portal.ScreenCast" = "wlr";

  xdg.portal.extraPortals = [
    # xdpw 0.8.3+ drives the PipeWire graph itself but only re-triggers it
    # from the ext-image-copy-capture backend. niri only offers wlr-screencopy,
    # so every screencast stalls after one frame (xdpw#390, #395). Upstream
    # fix c0255d7 (needs refactor ccd8e62) is on master after 0.8.4.
    # Drop the patches once nixpkgs ships xdg-desktop-portal-wlr > 0.8.4.
    (pkgs.xdg-desktop-portal-wlr.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          name = "xdpw-factor-out-wlr_frame_done.patch";
          url = "https://github.com/emersion/xdg-desktop-portal-wlr/commit/ccd8e629f49e65e401a977525593e80767ccdfb0.patch";
          hash = "sha256-c85Tr4tX7gTL14rlrK5zIUdyV3sVvkKV+K/p/y58Mpg=";
        })
        (pkgs.fetchpatch {
          name = "xdpw-trigger-graph-from-wlr-screencopy.patch";
          url = "https://github.com/emersion/xdg-desktop-portal-wlr/commit/c0255d7b047b7263629ab5a314661045ff7f65e3.patch";
          hash = "sha256-eKDA9vvztxqK0YEFWXEVN2zqPXYvuEaC32kfrwR2FIM=";
        })
      ];
    }))
  ];
}
