# Steam, GE-Proton and other game launchers.
{ pkgs, ... }:

{
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
