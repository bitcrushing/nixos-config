# Mouse and input tools.
{ pkgs, ... }:

{
  # Razer Basilisk V3 Pro 35K (1532:00cd): OpenRazer kernel driver + user daemon.
  hardware.openrazer = {
    enable = true;
    users = [ "bitcrushing" ];
  };

  # Remaps extra mouse buttons at the evdev level (works under Wayland).
  services.input-remapper.enable = true;

  # input-remapper-gtk runs its key recorder through pkexec, and polkit no
  # longer installs pkexec setuid by default.
  security.polkit.enablePkexecWrapper = true;

  environment.systemPackages = with pkgs; [
    polychromatic # OpenRazer GUI
    usbutils # lsusb
  ];
}
