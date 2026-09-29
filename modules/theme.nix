# System-wide look: stylix applies one base16 colour scheme, fonts, cursor,
# icons and the wallpaper (modules/desktop/wallpaper.nix) to the targets
# listed below. Firefox follows the
# GTK theme.
#
# Apps without a usable stylix target read the palette themselves via
# `config.lib.stylix.colors` (baseXX = "rrggbb", withHashtag.baseXX = "#rrggbb"):
#   - niri borders/cursor, mako and fuzzel borders ... modules/desktop/niri.nix
#   - waybar CSS ...................................... modules/desktop/waybar.nix
#   - pi .............................................. modules/pi/default.nix
# Neovim uses the official Rosé Pine plugin instead (modules/editors/neovim.nix),
# so it won't follow a scheme change here.
#
# Palette preview: ~/.config/stylix/palette.html
{ lib, pkgs, ... }:

let
  # Explicit list so it's obvious what stylix touches. Adding an app here
  # is usually all it takes to theme it.
  systemTargets = [
    "console"
    "fontconfig"
    "font-packages"
    "gtk"
    "qt"
  ];
  homeTargets = [
    "fontconfig"
    "font-packages"
    "gtk"
    "qt"
    "bat"
    "btop"
    "fzf"
    "fuzzel"
    "ghostty"
    "mako"
    "mpv"
    "spicetify"
    "swaylock"
    "vesktop"
    "waybar"
  ];
  enable =
    names:
    lib.genAttrs names (_: {
      enable = true;
    });
in

{
  stylix = {
    enable = true;
    autoEnable = false;
    targets = enable systemTargets;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
    # The base16 port maps base07 to a dark grey ("highlight high"), which
    # terminals then use as bright white. Use the text colour instead.
    override.base07 = "e0def4";

    # image: generated in modules/desktop/wallpaper.nix

    cursor = {
      package = pkgs.rose-pine-cursor;
      name = "BreezeX-RosePine-Linux";
      size = 24;
    };

    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme.override { color = "violet"; }; # folder colour
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };

    fonts = {
      sansSerif = {
        package = pkgs.atkinson-hyperlegible-next;
        name = "Atkinson Hyperlegible Next";
      };
      monospace = {
        package = pkgs.atkinson-nerdfont;
        name = "AtkynsonMono Nerd Font Mono";
      };
      sizes = {
        applications = 12;
        desktop = 11; # waybar
        popups = 12; # mako, fuzzel
        terminal = 11;
      };
    };

    # Translucent surfaces get blurred by niri (modules/desktop/niri/config.kdl).
    opacity = {
      terminal = 0.6; # ghostty, vesktop
      desktop = 0.65; # waybar
      popups = 0.92; # mako, fuzzel
    };
  };

  hm.stylix = {
    autoEnable = false;
    targets = enable homeTargets;
  };

  # Dark-mode preference read through the settings portal by Firefox,
  # libadwaita and Electron apps. (stylix only sets it in its GNOME target.)
  hm.dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
  ];
}
