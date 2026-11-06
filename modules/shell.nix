# Terminal environment: bash, CLI tools, git, ghostty.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # nh builds as the user with nom output, prints a diff of what changed, and
  # only then asks for sudo to activate, so the password prompt isn't hidden
  # behind the build progress. (Its `clean` feature stays off: it would also
  # delete devenv/direnv GC roots. Garbage collection is in configuration.nix.)
  # The aliases below pass the flake path explicitly; NH_FLAKE (from `flake`)
  # only reaches shells after a fresh login, and covers plain `nh os ...`.
  programs.nh = {
    enable = true;
    flake = "/home/bitcrushing/nixos";
  };

  hm = {
    programs.bash = {
      enable = true;
      shellAliases = {
        nrs = "nh os switch ~/nixos"; # build, show diff, sudo, activate + boot entry
        # build only (no sudo). The result link goes to /tmp (wiped on boot) so
        # stray ./result links don't keep old systems from being collected.
        nrb = "nh os build ~/nixos --out-link /tmp/nixos-build-result";
        nrt = "nh os test ~/nixos"; # activate without adding a boot entry

        # GUI apps whose command names don't say what they do. All go through
        # `launch` (below), so the terminal stays usable and quiet.
        open = "launch xdg-open"; # any file, in its default app
        img = "launch loupe";
        pdf = "launch papers";
        audio = "launch org.gnome.Decibels";
        decibels = "launch org.gnome.Decibels";
        archive = "launch file-roller";
        mixer = "launch pavucontrol";
        writer = "launch libreoffice --writer";
        calc = "launch libreoffice --calc";
        razer = "launch polychromatic-controller";
        remap = "launch input-remapper-gtk";
        discord = "launch vesktop";

        # Bluetooth settings are Noctalia's control-center tab (attached
        # panel), not a separate manager window.
        bt = "noctalia msg panel-toggle control-center bluetooth";
      };
      initExtra = ''
        PS1='\[\033[01;34m\]\u@\h:\w\[\033[00m\]\$ '

        # Start a GUI app detached from this terminal: no log noise, and it
        # keeps running if the terminal closes. `launch <command> [args]`
        launch() { setsid -f "$@" >/dev/null 2>&1; }
        # File manager, in the current directory unless given paths.
        files() { launch nautilus "''${@:-.}"; }
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

    # Colours and opacity come from stylix.
    programs.ghostty = {
      enable = true;
      settings = {
        # Spleen 12x24 (installed in theme.nix), with Symbols Nerd Font Mono
        # filling the Nerd glyphs Spleen lacks. Stylix also sets family and
        # size, hence mkForce. 18pt is pixel-perfect: 24px em at 96 DPI.
        font-family = lib.mkForce [
          "Spleen 12x24"
          "Symbols Nerd Font Mono"
          config.stylix.fonts.emoji.name
        ];
        font-size = lib.mkForce 18;
        font-style = "Medium"; # Spleen's only style
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
