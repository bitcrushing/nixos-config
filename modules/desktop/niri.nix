# niri session: login, compositor config, wallpaper, notifications,
# launcher and lock screen. Colours come from stylix (modules/theme.nix);
# gaps and borders from ./style.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  colors = config.lib.stylix.colors;
  style = import ./style.nix;
  hex = slot: colors.withHashtag.${slot};
  inherit (style) gaps border;
in
{
  # The niri module also sets up the GNOME/GTK portals, gnome-keyring,
  # polkit and the swaylock PAM service.
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user = "greeter";
    };
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    playerctl # media keys in binds.kdl
    libnotify # notify-send (used by pi's notify-mako extension)
    xwayland-satellite # X11 apps; niri starts it automatically when on PATH
    lxqt.lxqt-policykit # polkit agent; niri ships none
  ];

  hm = {
    xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
    xdg.configFile."niri/binds.kdl".source = ./niri/binds.kdl;
    xdg.configFile."niri/nix.kdl".text = ''
      cursor {
        xcursor-theme "${config.stylix.cursor.name}"
        xcursor-size ${toString config.stylix.cursor.size}
        hide-when-typing
      }

      // Alt-Tab / Mod+Tab switcher, in the window border colour.
      recent-windows {
        highlight {
          active-color "${hex border.focused}"
          urgent-color "${hex border.focused}"
          corner-radius 0
        }
      }

      // A window being screen-shared (e.g. in Vesktop) gets a red border.
      // Fullscreen windows have no border, so it never covers a movie.
      // Only applies to single-window shares, not whole-monitor ones.
      window-rule {
        match is-window-cast-target=true
        border {
          active-color "${colors.withHashtag.base08}"
          inactive-color "${colors.withHashtag.base08}"
        }
      }

      layout {
        gaps ${toString gaps}
        border {
          on
          width ${toString border.width}
          active-color "${hex border.focused}"
          inactive-color "${hex border.unfocused}"
          urgent-color "${hex border.focused}"
        }
      }
    '';

    services.mako = {
      enable = true;
      settings = {
        anchor = "top-right";
        # outer-margin offsets the whole surface from the screen edge (so it
        # meets a maximized window's corner); margin is padding *inside* the
        # surface, so only use it for the gap between stacked notifications.
        # directional: top,right,bottom,left
        outer-margin = "${toString gaps},${toString gaps},0,0";
        margin = "0,0,${toString gaps},0";
        border-size = border.width;
        border-radius = 0;
        # stylix colours normal borders base0D and critical ones base08.
        border-color = lib.mkForce (hex border.focused);
        "urgency=critical".border-color = lib.mkForce (hex border.focused);
        default-timeout = 5000;
      };
    };

    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          prompt = ">";
          line-height = 20;
          inner-pad = 8;
        };
        border = {
          inherit (border) width;
          radius = 0;
        };
        colors.border = lib.mkForce "${colors.${border.focused}}ff"; # stylix: base0D
      };
    };

    # stylix sets the wallpaper and colours; the overrides keep a thin ring
    # over a clear background.
    programs.swaylock = {
      enable = true;
      settings = {
        indicator-radius = 100;
        indicator-thickness = 4;
        inside-color = lib.mkForce "00000000";
        inside-clear-color = lib.mkForce "00000000";
        inside-ver-color = lib.mkForce "00000000";
        inside-wrong-color = lib.mkForce "00000000";
        inside-caps-lock-color = lib.mkForce "00000000";
        ring-color = lib.mkForce colors.base05;
        font = config.stylix.fonts.sansSerif.name;
        font-size = 20;
        ignore-empty-password = true;
        show-failed-attempts = true;
        disable-caps-lock-text = true;
      };
    };
  };
}
