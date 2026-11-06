# Wallpaper: a twilight lake generated at build time from the stylix palette
# (assets/wallpaper/generate.py), split across the monitors. A small native
# Wayland client animates sky/details plus a low-cadence film pass.
{ config, pkgs, ... }:

let
  # Left to right; must match the output positions in niri/config.kdl.
  # The generator assumes each is 1920x1080.
  outputs = [
    "HDMI-A-1"
    "HDMI-A-2"
  ];
  texture = "paintcrush"; # paint | crush (bitcrushed) | paintcrush | none
  fps = 24; # Subpixel sky interpolation; still below the monitors' refresh rate.
  grainFps = 8; # Gentle emulsion movement, not a 24 fps screen of noise.
  grainStrength = 0.8; # 0 disables grain and the faint exposure drift.

  c = config.lib.stylix.colors;
  palette = map (n: c."base0${n}") [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "A"
    "B"
    "C"
    "D"
    "E"
    "F"
  ];
  python = pkgs.python3.withPackages (ps: [
    ps.numpy
    ps.pillow
  ]);
  # Machine-specific: build locally and skip cache lookups. Animation needs
  # only one base image plus sprite coordinates, not hundreds of GIF frames.
  wallpaper =
    pkgs.runCommand "wallpaper-twilight-${c.slug}-${texture}"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        ${python}/bin/python3 ${../../assets/wallpaper/generate.py} \
          ${toString (1920 * builtins.length outputs)} 1080 $out ${texture} ${toString palette}
        ${pkgs.twilight-wallpaper}/bin/twilight-wallpaper --check $out ${toString outputs}
      '';
in
{
  # Required by stylix (and the source of the image below).
  stylix.image = "${wallpaper}/full.png";

  # Retain the still for Noctalia's wallpaper picker, but don't
  # keep a second pair of desktop wallpaper surfaces underneath the renderer.
  hm.programs.noctalia.settings.wallpaper = {
    enabled = false;
    fill_mode = "span";
    default.path = "${wallpaper}/full.png";
  };
  # Disabling Noctalia's desktop wallpaper also disables its lock wallpaper
  # fallback, so supply the still explicitly.
  hm.programs.noctalia.settings.lockscreen.wallpaper = "${wallpaper}/full.png";

  hm.systemd.user.services.twilight-wallpaper = {
    Unit = {
      Description = "Twilight wallpaper (sky, film grain and ambient details)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.twilight-wallpaper}/bin/twilight-wallpaper ${wallpaper} ${toString outputs}";
      Environment = [
        "TWILIGHT_FPS=${toString fps}"
        "TWILIGHT_GRAIN_FPS=${toString grainFps}"
        "TWILIGHT_GRAIN_STRENGTH=${toString grainStrength}"
      ];
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Same image on the login screen (greeter span mode slices per output too).
  services.displayManager.noctalia-greeter.settings.appearance.wallpaper = {
    path = "${wallpaper}/full.png";
    fill_mode = "span";
  };
}
