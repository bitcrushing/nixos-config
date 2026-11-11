# CLI tools, git and nh. Interactive shell helpers are in bash.nix.
{ pkgs, ... }:

{
  # nh builds as the user with nom output, prints a diff of what changed, and
  # only then asks for sudo to activate, so the password prompt isn't hidden
  # behind the build progress. (Its `clean` feature stays off: it would also
  # delete devenv/direnv GC roots. Garbage collection is in system/nix.nix.)
  # The aliases in bash.nix pass the flake path explicitly; NH_FLAKE (from
  # `flake`) only reaches shells after a fresh login, and covers plain
  # `nh os ...`.
  programs.nh = {
    enable = true;
    flake = "/home/bitcrushing/nixos";
  };

  hm = {
    home.packages = with pkgs; [
      p7zip
      unzip
      tree
      fastfetch
      nix-output-monitor # `nom`, readable build output (nh uses it too)
      scrcpy
      android-tools
    ];

    programs.git = {
      enable = true;
      settings.user = {
        name = "bitcrushing";
        email = "kakodaemon@protonmail.com";
      };
    };

    programs.btop.enable = true;
    programs.jq.enable = true;
    programs.bat.enable = true; # cat with syntax highlighting (stylix theme)
    programs.eza = {
      enable = true; # ls replacement; aliases ls/ll/la/lt/lla
      enableBashIntegration = true;
      git = true;
      icons = "auto";
    };
    programs.fzf = {
      enable = true; # Ctrl+R history search, Ctrl+T file picker, Alt+C cd
      enableBashIntegration = true;
    };
    programs.zoxide = {
      enable = true; # `z <part of a path>` jumps to frequently used dirs; `zi` to pick
      enableBashIntegration = true;
    };
  };
}
