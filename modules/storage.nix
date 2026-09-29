# Filesystems beyond hardware-configuration.nix, plus a weekly scrub.
# Both / (nvme0n1p1) and /mnt/data (sda) are bcachefs.
{ pkgs, ... }:

{
  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "bcachefs";
  };

  # Verifies checksums and corrects errors where possible; affected paths
  # are logged to the kernel log (`journalctl -k -g bcachefs`).
  systemd.services.bcachefs-scrub = {
    description = "Scrub bcachefs filesystems";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.bcachefs-tools}/bin/bcachefs scrub /"
        "${pkgs.bcachefs-tools}/bin/bcachefs scrub /mnt/data"
      ];
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.bcachefs-scrub = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true; # catch up if the PC was off at the scheduled time
    };
  };
}
