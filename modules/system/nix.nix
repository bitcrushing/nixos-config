# Nix daemon settings, the local package overlay, and garbage collection.
{ config, ... }:

{
  nixpkgs.overlays = [ (import ../../pkgs) ];
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true; # hard-link identical files in the store

  # Housekeeping: weekly, keep the 5 newest system generations and delete
  # everything no longer referenced. The boot menu lists at most 5.
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  systemd.services.nix-gc.preStart = "${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +5";
}
