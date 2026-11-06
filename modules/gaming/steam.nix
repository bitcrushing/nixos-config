# Steam, GE-Proton and other game launchers.
{ pkgs, ... }:

{
  # 32-bit Mesa for 32-bit Proton titles.
  hardware.graphics.enable32Bit = true;

  # Split-lock mitigation ("misery mode") tanks FPS in affected Proton games;
  # fine to drop on a personal desktop.
  boot.kernelParams = [ "split_lock_mitigate=0" ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    # Shows up in Steam as "GE-Proton" (the name stays the same across
    # updates, so per-game selections survive `nix flake update`).
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  hm.home.packages = with pkgs; [
    bottles
    prismlauncher # Minecraft
    protontricks
  ];
}
