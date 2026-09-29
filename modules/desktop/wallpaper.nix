# Wallpaper: a twilight lake generated at build time from the stylix palette
# (assets/wallpaper/generate.py), one wide image split across the monitors.
{ config, pkgs, ... }:

let
  # Left to right; must match the output positions in niri/config.kdl.
  # The generator assumes each is 1920x1080.
  outputs = [
    "HDMI-A-1"
    "HDMI-A-2"
  ];
  texture = "paintcrush"; # paint | crush (bitcrushed) | paintcrush | none

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
  wallpaper = pkgs.runCommand "wallpaper-twilight-${c.slug}-${texture}" { } ''
    ${python}/bin/python3 ${../../assets/wallpaper/generate.py} \
      ${toString (1920 * builtins.length outputs)} 1080 $out ${texture} ${toString palette}
  '';

  perOutput = pkgs.lib.concatImapStringsSep " " (
    i: o: "-o ${o} -i ${wallpaper}/${toString (i - 1)}.png -m fill"
  ) outputs;
in
{
  # Also used by the lock screen (swaylock scales it to fill each monitor).
  stylix.image = "${wallpaper}/full.png";

  # A user service rather than niri's spawn-at-startup, so a switch restarts
  # it with the new image instead of waiting for the next login.
  hm.systemd.user.services.swaybg = {
    Unit = {
      Description = "Wallpaper (swaybg)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg ${perOutput}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
