{ config, pkgs, lib, ... }:

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

    # Desktop apps
    discord
    syncplay
    libreoffice
    qbittorrent
    spotify-player

    # Gaming
    lutris
    bottles
    protonup-qt
    prismlauncher

    # Audio tooling (GUIs)
    qpwgraph
    qjackctl
    pavucontrol

    # Language servers & formatters for Helix
    nil                  # nix LSP
    nixfmt               # provides the `nixfmt` binary (RFC-style)
    rust-analyzer        # rust LSP
    ruff                 # python lint + format
    typescript-language-server
    prettier
    vscode-langservers-extracted   # json/html/css LSP
    taplo                # toml LSP + formatter
    yaml-language-server # yaml LSP
    marksman             # markdown LSP

    # Custom packages
    (pkgs.callPackage ./pkgs/pipeasio {})
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
  home.activation.pipeasioLocalWine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $HOME/.local/lib/wine/x86_64-unix $HOME/.local/lib/wine/x86_64-windows
    $DRY_RUN_CMD cp -Lf --no-preserve=mode ${pkgs.callPackage ./pkgs/pipeasio {}}/lib/wine/x86_64-unix/* $HOME/.local/lib/wine/x86_64-unix/
    $DRY_RUN_CMD cp -Lf --no-preserve=mode ${pkgs.callPackage ./pkgs/pipeasio {}}/lib/wine/x86_64-windows/* $HOME/.local/lib/wine/x86_64-windows/
  '';

  programs.ghostty = {
    enable = true;
    settings = {
      # base16 default dark (matches helix base16_default_dark)
      background = "181818";
      foreground = "d8d8d8";
      cursor-color = "d8d8d8";
      selection-background = "383838";
      selection-foreground = "d8d8d8";
      palette = [
        "0=#181818"  "1=#ab4642"  "2=#a1b56c"  "3=#f7ca88"
        "4=#7cafc2"  "5=#ba8baf"  "6=#86c1b9"  "7=#d8d8d8"
        "8=#585858"  "9=#ab4642"  "10=#a1b56c" "11=#f7ca88"
        "12=#7cafc2" "13=#ba8baf" "14=#86c1b9" "15=#f8f8f8"
      ];
      background-opacity = "0.95";
      font-family = "monospace";
      font-size = 12;
      cursor-style = "block";
      cursor-style-blink = false;
    };
  };
  
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "base16_default_dark";
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
          formatter = { command = "nixfmt"; };
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
