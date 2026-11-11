# Filesystems beyond hardware-configuration.nix, plus a weekly scrub.
# Both / (nvme0n1p1) and /mnt/data (sda) are bcachefs.
{ ... }:

{
  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "bcachefs";
  };

  # Weekly scrub of every bcachefs mount (checksum verification, repairs
  # where a good copy exists); findings land in the kernel log
  # (`journalctl -k -g bcachefs`).
  services.bcachefs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # Compressed RAM swap in front of the disk partition: absorbs pressure
  # spikes (games, DAW work) without touching the SSD. High swappiness so
  # the kernel actually uses it instead of dropping file cache.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  boot.kernel.sysctl."vm.swappiness" = 180;
}
