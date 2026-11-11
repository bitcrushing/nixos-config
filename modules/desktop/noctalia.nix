# Desktop shell: bar, launcher, notifications, clipboard history, session
# menu, lock screen + idle handling, volume OSD and polkit agent. This replaces
# the old waybar/mako/fuzzel/swaylock/swayidle/swayosd stack; don't add those
# back.
# Keybindings that drive it live in niri/binds.kdl (`noctalia msg ...`).
#
# These settings are the Nix-owned base layer (~/.config/noctalia/config.toml,
# validated at build time). Changes made in Noctalia's Settings GUI persist
# separately in ~/.local/state/noctalia/settings.toml and win over these.
{ config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
in
{
  hm.programs.noctalia = {
    enable = true;
    systemd.enable = true; # start with the graphical session

    settings = {
      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "rose-pine-moon";
      };

      shell = {
        polkit_agent = true; # replaces lxqt-policykit-agent (was spawn-at-startup in config.kdl)
        setup_wizard_enabled = false; # configured declaratively; don't pop the wizard
        # Panels anchor to the bar at the clicked widget instead of floating
        # centered (control-center and session already default to attached).
        panel = {
          launcher_placement = "attached";
          clipboard_placement = "attached";
          wallpaper_placement = "attached";
          polkit_placement = "attached";
          # Without these, panels open on the focused monitor: a widget
          # clicked on one screen pops its panel up on the other. Open them
          # near the click instead.
          open_near_click_launcher = true;
          open_near_click_clipboard = true;
          open_near_click_control_center = true;
          open_near_click_session = true;
          open_near_click_wallpaper = true;
        };
      };

      # Noctalia's panel slide renders a full-size flash on open/close
      # (upstream quirk; niri has no layer animation to conflict with), still
      # visible at 2x speed. Motion off: panels pop in/out instantly.
      shell.animation.enabled = false;

      # Workspaces left, clock centre, and a small status group right. The
      # bell opens notification history; control-center consolidates
      # wifi/bluetooth/audio/settings. CPU/RAM text was dropped on purpose —
      # both live in the control center and system monitor; add "cpu" and
      # "ram" back to `end` below if you miss the at-a-glance numbers.
      # Full-width (margin_ends = 0) with square corners (radius = 0);
      # translucency follows stylix.
      bar.default = {
        position = "top";
        reserve_space = true;
        thickness = 28;
        margin_ends = 0;
        background_opacity = config.stylix.opacity.desktop;
        radius = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;
        start = [ "workspaces" ];
        center = [ "clock" ];
        end = [
          "tray"
          "notifications"
          "network"
          "volume"
          "control-center"
        ];
      };

      # Short agenda day header ("Wed 14 Oct"): the default "%A %e %B"
      # overflows its column ("Wednesday 14 Octo…").
      calendar.event_date_format = "%a %e %b";

      # Lock after 10 minutes, monitors off after 15. Suspend locking is
      # built in (lockscreen.lock_before_suspend).
      idle.behavior = {
        lock = {
          timeout = 600;
          action = "lock";
          enabled = true;
        };
        screen-off = {
          timeout = 900;
          action = "screen_off";
          enabled = true;
        };
      };

      # Allow locking with an empty password, like the previous lock screen.
      lockscreen.allow_empty_password = true;
    };

    # Rosé Pine Moon, generated from the stylix palette so a scheme change
    # follows the rest of the desktop. Dark variant only: the shell runs
    # dark (theme.mode above), and a missing light variant falls back to it.
    customPalettes.rose-pine-moon.dark = {
      mPrimary = c.base0D;
      mOnPrimary = c.base00;
      mSecondary = c.base0C;
      mOnSecondary = c.base00;
      mTertiary = c.base0A;
      mOnTertiary = c.base00;
      mError = c.base08;
      mOnError = c.base00;
      mSurface = c.base00;
      mOnSurface = c.base05;
      mSurfaceVariant = c.base01;
      mOnSurfaceVariant = c.base04;
      mOutline = c.base02;
      mShadow = c.base00;
      mHover = c.base02;
      mOnHover = c.base05;
      terminal = {
        background = c.base00;
        foreground = c.base05;
        cursor = c.base05;
        cursorText = c.base00;
        selectionBg = c.base02;
        selectionFg = c.base05;
        normal = {
          black = c.base00;
          red = c.base08;
          green = c.base0B;
          yellow = c.base0A;
          blue = c.base0D;
          magenta = c.base0E;
          cyan = c.base0C;
          white = c.base05;
        };
        bright = {
          black = c.base03;
          red = c.base08;
          green = c.base0B;
          yellow = c.base0A;
          blue = c.base0D;
          magenta = c.base0E;
          cyan = c.base0C;
          white = c.base07;
        };
      };
    };
  };
}
