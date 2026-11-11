# Interactive bash: prompt, aliases and small shell helpers.
{ ... }:

{
  hm.programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "nh os switch ~/nixos"; # build, show diff, sudo, activate + boot entry
      # build only (no sudo). The result link goes to /tmp (wiped on boot) so
      # stray ./result links don't keep old systems from being collected.
      nrb = "nh os build ~/nixos --out-link /tmp/nixos-build-result";
      nrt = "nh os test ~/nixos"; # activate without adding a boot entry

      # GUI apps whose command names don't say what they do. All go through
      # `launch` (below), so the terminal stays usable and quiet.
      open = "launch xdg-open"; # any file, in its default app
      img = "launch loupe";
      pdf = "launch papers";
      audio = "launch org.gnome.Decibels";
      decibels = "launch org.gnome.Decibels";
      archive = "launch file-roller";
      mixer = "launch pavucontrol";
      writer = "launch libreoffice --writer";
      calc = "launch libreoffice --calc";
      razer = "launch polychromatic-controller";
      remap = "launch input-remapper-gtk";
      discord = "launch vesktop";

      # Bluetooth settings are Noctalia's control-center tab (attached
      # panel), not a separate manager window.
      bt = "noctalia msg panel-toggle control-center bluetooth";
    };
    initExtra = ''
      PS1='\[\033[01;34m\]\u@\h:\w\[\033[00m\]\$ '

      # Start a GUI app detached from this terminal: no log noise, and it
      # keeps running if the terminal closes. `launch <command> [args]`
      launch() { setsid -f "$@" >/dev/null 2>&1; }
      # File manager, in the current directory unless given paths.
      files() { launch nautilus "''${@:-.}"; }
    '';
  };
}
