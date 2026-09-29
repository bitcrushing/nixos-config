# Status bar. Started by systemd with the niri session. stylix provides the
# font and the @base00..@base0F colours; the look below matches the flat,
# square desktop (borders from ./style.nix).
{ config, ... }:

let
  style = import ./style.nix;
in
{
  hm = {
    stylix.targets.waybar = {
      font = "sansSerif";
      addCss = false; # keep stylix's colours and font, use the CSS below
    };

    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings.main = {
        layer = "top";
        position = "top";
        height = 28;
        spacing = 0;
        modules-left = [ "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "cpu"
          "memory"
          "pulseaudio"
          "network"
          "tray"
        ];

        # Icons are Nerd Font glyphs (nf-fa-circle / circle_o / exclamation_circle,
        # microphone_slash, chain_broken).
        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            focused = "";
            default = "";
            urgent = "";
          };
        };
        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%A %d %B %Y}";
        };
        cpu = {
          format = "CPU {usage:>2}%";
          tooltip = false;
        };
        memory = {
          format = "MEM {used} / {total}";
          tooltip = false;
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = " muted";
          on-click = "pavucontrol";
        };
        network = {
          format = "{essid} ({signalStrength}%)";
          format-disconnected = " down";
        };
        tray.spacing = 6;
      };

      style = ''
        window#waybar {
          background: alpha(@base00, ${toString config.stylix.opacity.desktop});
          color: @base05;
          border-bottom: ${toString style.border.width}px solid @${style.border.unfocused};
        }

        tooltip {
          background: @base00;
          border: ${toString style.border.width}px solid @${style.border.focused};
          border-radius: 0;
        }
        tooltip label {
          color: @base05;
        }

        #workspaces button {
          all: unset;
          padding: 0 6px;
          color: @base03;
        }
        #workspaces button.active {
          color: @base05;
        }
        #workspaces button:hover {
          background: @base01;
        }

        #clock,
        #cpu,
        #memory,
        #pulseaudio,
        #network,
        #tray {
          padding: 0 10px;
        }
        #cpu,
        #memory {
          color: @base04;
        }
        #pulseaudio.muted,
        #network.disconnected {
          color: @base03;
        }
      '';
    };
  };
}
