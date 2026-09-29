# Terminal environment: bash, CLI tools, git, ghostty.
{ config, pkgs, ... }:

{
  # nh builds as the user with nom output, prints a diff of what changed, and
  # only then asks for sudo to activate, so the password prompt isn't hidden
  # behind the build progress. (Its `clean` feature stays off: it would also
  # delete devenv/direnv GC roots. Garbage collection is in configuration.nix.)
  programs.nh = {
    enable = true;
    flake = "/home/bitcrushing/nixos";
  };

  hm = {
    programs.bash = {
      enable = true;
      shellAliases = {
        nrs = "nh os switch"; # build, show diff, sudo, activate + boot entry
        # build only (no sudo). The result link goes to /tmp (wiped on boot) so
        # stray ./result links don't keep old systems from being collected.
        nrb = "nh os build --out-link /tmp/nixos-build-result";
        nrt = "nh os test"; # activate without adding a boot entry
      };
      initExtra = ''
        PS1='\[\033[01;34m\]\u@\h:\w\[\033[00m\]\$ '
      '';
    };

    # EDITOR comes from programs.neovim.defaultEditor.
    home.sessionVariables = {
      VISUAL = "nvim";
      SUDO_EDITOR = "nvim";
    };

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

    # Colours, font family/size and opacity come from stylix.
    programs.ghostty = {
      enable = true;
      settings = {
        font-style = "Medium";
        font-feature = [
          "zero" # slashed zero
          "case" # case-sensitive punctuation
        ];
        cursor-style = "block";
        cursor-style-blink = false;
        scrollbar = "never"; # scrolling still works
        # Apply background-opacity to cells with their own background colour
        # too (pi's panels, nvim floats), not just the default background.
        background-opacity-cells = true;
        window-title-font-family = config.stylix.fonts.sansSerif.name;
      };
    };
  };
}
