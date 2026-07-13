# Niri session configuration: compositor config, status bar, notifications,
# and application launcher. Contributed to home-manager (merges with
# home.nix and theme.nix).
{ ... }:

{
  home-manager.users.bitcrushing = {
    # ── Niri compositor ────────────────────────────────────────
    xdg.configFile."niri/config.kdl".text = ''
      // Monet dusk — Niri scrollable-tiling compositor
      input {
        keyboard {
          xkb {
            layout "us"
          }
        }
        touchpad {
          tap;
          natural-scroll;
          click-method "clickfinger";
        }
      }

      // Bar, notifications and wallpaper at startup
      spawn-at-startup "waybar"
      spawn-at-startup "mako"
      spawn-at-startup "swaybg" "-i" "${./wallpaper.jpg}" "-m" "fill"

      // Ask clients to drop client-side decorations so the focus ring draws
      // *around* windows instead of as a square behind them.
      prefer-no-csd

      layout {
        gaps 8;
        preset-column-widths {
          proportion 0.1;
          proportion 0.2;
          proportion 0.3;
          proportion 0.4;
          proportion 0.5;
          proportion 0.6;
        }
        default-column-width { proportion 0.5; }

        focus-ring {
          width 2;
          active-color "#6886b066";
          inactive-color "#36334244";
          urgent-color "#b57a82aa";
        }

        border {
          width 2;
          active-color "#6886b0";
          inactive-color "#363342";
        }
      }

      binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Terminal (default uses Mod+T + alacritty; changed to Mod+Return + ghostty)
        Mod+Return hotkey-overlay-title="Open a Terminal: ghostty" { spawn "ghostty"; }
        Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }

        // Volume keys (PipeWire/WirePlumber) — work even when locked
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

        // Media keys (playerctl)
        XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

        Mod+O repeat=false { toggle-overview; }

        Mod+Q repeat=false { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+L     { focus-column-right; }

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }
        Mod+Ctrl+Home { move-column-to-first; }
        Mod+Ctrl+End  { move-column-to-last; }

        Mod+Shift+Left  { focus-monitor-left; }
        Mod+Shift+Down  { focus-monitor-down; }
        Mod+Shift+Up    { focus-monitor-up; }
        Mod+Shift+Right { focus-monitor-right; }
        Mod+Shift+H     { focus-monitor-left; }
        Mod+Shift+J     { focus-monitor-down; }
        Mod+Shift+K     { focus-monitor-up; }
        Mod+Shift+L     { focus-monitor-right; }

        Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
        Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

        Mod+Page_Down      { focus-workspace-down; }
        Mod+Page_Up        { focus-workspace-up; }
        Mod+U              { focus-workspace-down; }
        Mod+I              { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
        Mod+Ctrl+U         { move-column-to-workspace-down; }
        Mod+Ctrl+I         { move-column-to-workspace-up; }

        Mod+Shift+Page_Down { move-workspace-down; }
        Mod+Shift+Page_Up   { move-workspace-up; }
        Mod+Shift+U         { move-workspace-down; }
        Mod+Shift+I         { move-workspace-up; }

        Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
        Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

        Mod+WheelScrollRight      { focus-column-right; }
        Mod+WheelScrollLeft       { focus-column-left; }
        Mod+Ctrl+WheelScrollRight { move-column-right; }
        Mod+Ctrl+WheelScrollLeft  { move-column-left; }

        Mod+Shift+WheelScrollDown      { focus-column-right; }
        Mod+Shift+WheelScrollUp        { focus-column-left; }
        Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
        Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }

        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-column-width-back; }

        Mod+Ctrl+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }

        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        Mod+M { maximize-window-to-edges; }

        Mod+Ctrl+F { expand-column-to-available-width; }

        Mod+C { center-column; }
        Mod+Ctrl+C { center-visible-columns; }

        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }

        Mod+W { toggle-column-tabbed-display; }

        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }

        Mod+Shift+P { power-off-monitors; }

        // Lock screen — thin ring, transparent inside, wallpaper background
        Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" {
          spawn-sh "swaylock --image ${./wallpaper.jpg} --scaling fill --indicator-radius 100 --indicator-thickness 4 --inside-color 00000000 --inside-clear-color 00000000 --inside-ver-color 00000000 --inside-wrong-color 00000000 --ring-color ddd2da --ring-clear-color 6886b0 --ring-ver-color 7d9aa8 --ring-wrong-color b57a82 --line-uses-ring --key-hl-color 6886b0 --bs-hl-color b57a82 --separator-color 00000000 --text-color c8bcc8 --font 'VictorMono Nerd Font' --font-size 20 --ignore-empty-password --show-failed-attempts --disable-caps-lock-text";
        }
      }

      // Optional: explicit two-monitor layout.
      // Names may differ — verify with `niri msg outputs` and adjust.
      output "HDMI-A-1" {
        position x=0 y=0;
      }
      output "HDMI-A-2" {
        position x=1920 y=0;
      }
    '';

    # ── Waybar (Niri) ─────────────────────────────────────────
    xdg.configFile."waybar/config".text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 28,
        "spacing": 4,
        "modules-left": ["niri/workspaces"],
        "modules-center": ["clock"],
        "modules-right": ["cpu", "memory", "pulseaudio", "network", "tray"],

        "niri/workspaces": {
          "format": "{icon}",
          "format-icons": {
            "active": "",
            "default": "",
            "focused": "",
            "urgent": ""
          }
        },
        "clock": {
          "format": "{:%H:%M}",
          "tooltip-format": "{:%A %d %B %Y}"
        },
        "cpu": { "format": "CPU {usage:>2}%", "tooltip": false },
        "memory": { "format": "MEM {used} / {total}", "tooltip": false },
        "pulseaudio": {
          "format": "{volume}% {icon}",
          "format-muted": " muted",
          "on-click": "pavucontrol"
        },
        "network": {
          "format": "{essid} ({signalStrength}%)",
          "format-disconnected": " down"
        },
        "tray": { "spacing": 4 }
      }
    '';

    xdg.configFile."waybar/style.css".text = ''
      * {
        font-family: "VictorMono Nerd Font";
        font-size: 13px;
      }
      window#waybar {
        background: rgba(32, 29, 33, 0.92);
        color: #c8bcc8;
        border-bottom: 2px solid #363342;
      }
      #workspaces button {
        color: #756a85;
        padding: 0 6px;
        border: none;
        box-shadow: none;
      }
      #workspaces button.focused { color: #6886b0; }
      #workspaces button.active { color: #c8bcc8; }
      #clock, #cpu, #memory, #pulseaudio, #network, #tray {
        padding: 0 8px;
      }
      #pulseaudio.muted { color: #b57a82; }
    '';

    # ── Mako notifications ────────────────────────────────────
    xdg.configFile."mako/config".text = ''
      border-size=2
      border-color=#6886b0
      background-color=#201d21
      text-color=#c8bcc8
      progress-color=source
      border-radius=8
      font=VictorMono Nerd Font 12
      anchor=top-right
      default-timeout=5000
    '';

    # ── Fuzzel application launcher ───────────────────────────
    xdg.configFile."fuzzel/config.ini".text = ''
      prompt=>
      font=VictorMono Nerd Font:size=12
      background-color=201d21ff
      text-color=c8bcc8ff
      prompt-color=6886b0ff
      selection-color=363342ff
      selection-text-color=ddd2daff
      border-color=363342ff
      border-size=2
      border-radius=8
      line-height=20
      padding=8
    '';
  };
}
