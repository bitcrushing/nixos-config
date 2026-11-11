# Screenshot helpers: whole-layout capture and annotation. niri's built-in
# Print binds are in niri/binds.kdl; lock/idle, OSD, launcher, clipboard and
# power menu are Noctalia (modules/desktop/noctalia.nix).
{ pkgs, ... }:

let
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
      screenshot-all
      annotate-screenshot
    ];

    programs.satty = {
      enable = true;
      settings.general = {
        initial-tool = "arrow";
        corner-roundness = 0; # square, like the rest of the desktop
      };
    };
  };
}
