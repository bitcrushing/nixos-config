# Session helpers: idle lock, volume/media OSD, clipboard history, screenshots
# (both monitors, annotation) and a power menu. Keybindings for them are in niri/binds.kdl.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = config.lib.stylix.colors.withHashtag;
  style = import ./style.nix;
  swaylock = "${pkgs.swaylock}/bin/swaylock";
  menu = prompt: "fuzzel --dmenu --prompt '${prompt} '";

  power-menu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.systemd
      pkgs.niri
    ];
    text = ''
      choice=$(printf '%s\n' Lock Suspend "Log out" Reboot "Shut down" | ${menu "power>"} --lines 5 --width 16) || exit 0
      case "$choice" in
        Lock) loginctl lock-session ;;
        Suspend) systemctl suspend ;; # swayidle locks before sleep
        "Log out") niri msg action quit --skip-confirmation ;;
        Reboot) systemctl reboot ;;
        "Shut down") systemctl poweroff ;;
      esac
    '';
  };

  clipboard-pick = pkgs.writeShellApplication {
    name = "clipboard-pick";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.fuzzel
      pkgs.wl-clipboard
    ];
    text = ''
      entry=$(cliphist list | ${menu "clip>"}) || exit 0
      cliphist decode <<<"$entry" | wl-copy
    '';
  };

  # niri's screenshot actions only capture one monitor; grim captures the whole
  # layout (both monitors, 3840x1080) into one image. Same folder and naming as
  # niri's screenshots, so annotate-screenshot picks it up too.
  screenshot-all = pkgs.writeShellApplication {
    name = "screenshot-all";
    runtimeInputs = [
      pkgs.grim
      pkgs.wl-clipboard
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
      grim "$file"
      wl-copy --type image/png < "$file"
      notify-send -a screenshot "Screenshot of both monitors" "Copied to the clipboard and saved to Pictures/Screenshots"
    '';
  };

  # niri's screenshot tools (Print, Ctrl/Alt+Print) save to ~/Pictures/Screenshots;
  # this opens the newest one in satty to draw on, then saves and copies the result.
  annotate-screenshot = pkgs.writeShellApplication {
    name = "annotate-screenshot";
    runtimeInputs = [
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.coreutils
      pkgs.findutils
      pkgs.libnotify
    ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      latest=$(find "$dir" -maxdepth 1 -name '*.png' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
      [ -n "$latest" ] || { notify-send "No screenshot to annotate" "Take one with Print first"; exit 0; }
      exec satty --filename "$latest" \
        --output-filename "$dir/Annotated %Y-%m-%d %H-%M-%S.png" \
        --copy-command wl-copy --early-exit
    '';
  };
in
{
  hm = {
    home.packages = [
      power-menu
      clipboard-pick
      screenshot-all
      annotate-screenshot
    ];

    # Lock after 10 minutes idle, monitors off after 15, always lock before
    # suspend. Apps that inhibit idle (video in Firefox/mpv, Steam while a
    # game runs) keep this from firing.
    services.swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/loginctl lock-session";
        }
        {
          timeout = 900;
          command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        }
      ];
      events = {
        lock = "${swaylock} -f";
        before-sleep = "${swaylock} -f";
      };
    };

    # On-screen display for volume and media keys, styled like mako.
    services.swayosd = {
      enable = true;
      stylePath = pkgs.writeText "swayosd.css" ''
        window#osd {
          border-radius: 0;
          border: ${toString style.border.width}px solid ${c.${style.border.focused}};
          background: alpha(${c.base00}, ${toString config.stylix.opacity.popups});
        }
        window#osd #container { margin: 12px 16px; }
        window#osd image, window#osd label { color: ${c.base05}; }
        window#osd progressbar:disabled, window#osd image:disabled { opacity: 0.5; }
        window#osd progressbar, window#osd segmentedprogress {
          min-height: 4px; border-radius: 0; border: none; background: transparent;
        }
        window#osd trough, window#osd segment {
          min-height: inherit; border-radius: 0; border: none; background: ${c.base02};
        }
        window#osd progress, window#osd segment.active {
          min-height: inherit; border-radius: 0; border: none; background: ${c.base05};
        }
        window#osd segment { margin-left: 6px; }
        window#osd segment:first-child { margin-left: 0; }
      '';
    };

    # Clipboard history (text and images); pick with clipboard-pick.
    services.cliphist = {
      enable = true;
      allowImages = true;
    };

    programs.satty = {
      enable = true;
      settings.general = {
        initial-tool = "arrow";
        corner-roundness = 0; # square, like the rest of the desktop
      };
    };
  };
}
