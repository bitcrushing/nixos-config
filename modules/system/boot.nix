# Boot loader and kernel.
{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_zen; # Zen: lower latency for games/audio (1000Hz, preempt)
  boot.tmp.cleanOnBoot = true; # /tmp is on the root disk, so it would otherwise never empty
}
