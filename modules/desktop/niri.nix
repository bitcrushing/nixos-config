# niri session: login, compositor config and wallpaper. The shell (bar,
# notifications, launcher, lock screen, polkit agent) is Noctalia
# (modules/desktop/noctalia.nix). Colours come from stylix (modules/theme.nix);
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
  # The niri module also sets up the GNOME/GTK portals, gnome-keyring and
  # polkit (Noctalia registers its own agent; see noctalia.nix).
  programs.niri.enable = true;

  # Graphical login: Noctalia greeter through greetd (replaces tuigreet).
  # The module owns the greetd command, state dir, AccountsService and
  # polkit; the login wallpaper lives with the image in wallpaper.nix.
  services.displayManager = {
    # Session files the greeter lists (nothing provided them while tuigreet
    # launched niri-session directly).
    sessionPackages = [ pkgs.niri ];
    noctalia-greeter = {
      enable = true;
      # One-click shell -> greeter appearance sync (else every sync prompts).
      passwordlessSyncUsers = [ "bitcrushing" ];
      cursorTheme = {
        package = config.stylix.cursor.package;
        name = config.stylix.cursor.name;
      };
      settings = {
        cursor.size = config.stylix.cursor.size;
        keyboard.layout = "us"; # same as the niri xkb layout in config.kdl
        session.default = "Niri";
        user.default = "bitcrushing"; # straight to the password step
        appearance = {
          scheme = "Synced";
          theme_mode = "dark";
          font_family = "sans-serif"; # resolves to Jost through fontconfig
          corner_radius_scale = 0; # square, like the rest of the desktop
          scheme_selector_position = "hidden"; # scheme is pinned above
          hide_logo = true; # no brand logo on the login screen
          # Rosé Pine Moon, mirroring the shell palette in noctalia.nix
          # (snake_case here, not the shell's m* names).
          palette = {
            primary = hex "base0D";
            on_primary = hex "base00";
            secondary = hex "base0C";
            on_secondary = hex "base00";
            tertiary = hex "base0A";
            on_tertiary = hex "base00";
            error = hex "base08";
            on_error = hex "base00";
            surface = hex "base00";
            on_surface = hex "base05";
            surface_variant = hex "base01";
            on_surface_variant = hex "base04";
            outline = hex "base02";
            shadow = hex "base00";
            hover = hex "base02";
            on_hover = hex "base05";
          };
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    libnotify # notify-send (screenshots, pi's notify-desktop extension)
    xwayland-satellite # X11 apps; niri starts it automatically when on PATH
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
  };
}
