# Host identity and always-on system services.
{ pkgs, ... }:

{
  networking.hostName = "PC";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Dublin";

  users.users.bitcrushing = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
    ];
  };

  security.sudo.extraConfig = ''
    Defaults env_editor
  '';

  # Process priority rules (CachyOS ruleset).
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # Kill runaway memory hogs early; the kernel's own OOM handling freezes
  # the desktop for a long time instead.
  services.earlyoom.enable = true;
}
