{
  config,
  pkgs,
  lib,
  ...
}:

{

  home.username = "bitcrushing";
  home.homeDirectory = "/home/bitcrushing";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos#PC";
      nrb = "nixos-rebuild build --flake ~/nixos#PC";
      nrt = "sudo nixos-rebuild test --flake ~/nixos#PC";
    };
  };

  home.sessionVariables = {
    SUDO_EDITOR = "hx";
    EDITOR = "hx";
  };

  home.packages = with pkgs; [
    # CLI utilities
    wget
    p7zip
    tree
    fastfetch
    opencode
    scrcpy
    android-tools

    # Desktop apps
    discord
    syncplay
    libreoffice
    qbittorrent
    spotify-player
    obsidian

    # Games
    lutris
    bottles
    protonup-qt
    protontricks
    prismlauncher
    vulkan-tools
    opentrack
    aitrack

    # Audio
    renoise
    qpwgraph
    qjackctl
    pavucontrol

    # Devenv, LSPs, formatters
    devenv
    nil # Nix LSP
    nixfmt
    rust-analyzer # Rust LSP
    ruff # Python lint + format
    typescript-language-server
    prettier
    vscode-langservers-extracted # JSON/HTML/CSS LSP
    taplo # TOML LSP + formatter
    yaml-language-server # YAML LSP
    marksman # Markdown LSP

    # Custom packages
    (pkgs.callPackage ./pkgs/pipeasio { })
  ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "bitcrushing";
      email = "kakodaemon@protonmail.com";
    };
  };

  programs.btop.enable = true;

  programs.mpv.enable = true;

  programs.obs-studio.enable = true;

  # PipeASIO's Wine/Proton loader needs the ELF .so half to live under $HOME
  # (the Proton container exposes home by default, but may not expose /nix/store).
  # Keep a local copy updated on every home-manager activation.
  # Also symlink the nix PipeWire lib so LD_PRELOAD can override the container's
  # ancient libpipewire-0.3 (steamrt ships 0.3.27; PipeASIO needs pw_data_loop_set_thread_utils).
  home.activation.pipeasioLocalWine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $HOME/.local/lib/wine/x86_64-unix $HOME/.local/lib/wine/x86_64-windows
    $DRY_RUN_CMD cp -Lf --no-preserve=mode ${
      pkgs.callPackage ./pkgs/pipeasio { }
    }/lib/wine/x86_64-unix/* $HOME/.local/lib/wine/x86_64-unix/
    $DRY_RUN_CMD cp -Lf --no-preserve=mode ${
      pkgs.callPackage ./pkgs/pipeasio { }
    }/lib/wine/x86_64-windows/* $HOME/.local/lib/wine/x86_64-windows/
    $DRY_RUN_CMD ln -sfn ${lib.getLib pkgs.pipewire}/lib $HOME/.local/lib/pipewire
  '';

  programs.ghostty.enable = true;

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        bufferline = "multiple";
        color-modes = true;
        true-color = true;
        soft-wrap = {
          enable = true;
        };
        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
        indent-guides = {
          render = true;
          character = "│";
          skip-levels = 1;
        };
      };
      keys.normal = {
        "C-h" = "jump_view_left";
        "C-j" = "jump_view_down";
        "C-k" = "jump_view_up";
        "C-l" = "jump_view_right";
      };
    };
    languages = {
      language-server.nil = {
        command = "nil";
      };
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = "nixfmt";
          };
          language-servers = [ "nil" ];
        }
        {
          name = "rust";
          auto-format = true;
        }
        {
          name = "python";
          auto-format = true;
        }
        {
          name = "javascript";
          auto-format = true;
        }
        {
          name = "typescript";
          auto-format = true;
        }
        {
          name = "json";
          auto-format = true;
        }
        {
          name = "toml";
          auto-format = true;
        }
        {
          name = "yaml";
          auto-format = true;
        }
        {
          name = "markdown";
          auto-format = true;
        }
      ];
    };
  };
}
