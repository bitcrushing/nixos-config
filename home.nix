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
      nrs = "sudo nixos-rebuild switch --flake ~/nixos#PC |& nom";
      nrb = "nixos-rebuild build --flake ~/nixos#PC |& nom";
      nrt = "sudo nixos-rebuild test --flake ~/nixos#PC |& nom";
    };
  };

  home.sessionVariables = {
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    # EDITOR=nvim comes from programs.neovim.defaultEditor below.
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
    nix-output-monitor # nom: prettier nix build output

    # LazyVim runtime requirements
    # (git, ripgrep, curl, tar, gzip and a Nerd Font are already installed)
    gcc # compiles tree-sitter parsers
    tree-sitter # CLI required by nvim-treesitter to build parsers
    bash-language-server # bashls for LazyVim util.dot extra (mason=false)
    fd # file finding for pickers
    lazygit # git TUI used by LazyVim
    unzip # mason.nvim archive extraction

    # Desktop apps
    discord
    syncplay
    libreoffice
    qbittorrent
    spotify-player
    obsidian
    krita

    # Games
    lutris
    bottles
    protonup-qt
    protontricks
    prismlauncher
    vulkan-tools
    opentrack

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

  programs.yazi = {
    enable = true;
    # `y` shell wrapper: exit yazi and land in its last directory.
    enableBashIntegration = true;

    plugins = {
      # Git status linemode in the file listing.
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true; # require("git"):setup() in init.lua
      };
      lazygit = pkgs.yaziPlugins.lazygit;
      smart-enter = pkgs.yaziPlugins.smart-enter;
    };

    keymap.mgr.prepend_keymap = [
      {
        on = [
          "g"
          "i"
        ];
        run = "plugin lazygit";
        desc = "Run lazygit";
      }
      {
        on = "l";
        run = "plugin smart-enter";
        desc = "Enter directory or open file";
      }
    ];
  };

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

  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets EDITOR=nvim
    viAlias = true;
    vimAlias = true;
    # LazyVim distribution. Config is nix-managed here; lazy.nvim installs
    # plugins to ~/.local/share/nvim at runtime (writable, outside the store).
    initLua = ''
      -- Bootstrap lazy.nvim
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = "https://github.com/folke/lazy.nvim.git"
        local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
        if vim.v.shell_error ~= 0 then
          vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
          }, true, {})
          vim.fn.getchar()
          os.exit(1)
        end
      end
      vim.opt.rtp:prepend(lazypath)

      require("lazy").setup({
        spec = {
          -- monet_dusk colorscheme: plain colors/ file managed in theme.nix
          { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "monet_dusk" } },
          -- OCaml: treesitter highlighting + LSP config (from LazyVim's lang extra)
          { import = "lazyvim.plugins.extras.lang.ocaml" },
          {
            "neovim/nvim-lspconfig",
            opts = {
              servers = {
                -- mason=false: server binaries come from nixpkgs (home.packages),
                -- not mason. bashls install via mason needs npm (absent) and
                -- errorred on every startup.
                bashls = { mason = false },
                ocamllsp = { mason = false },
              },
            },
          },
        },
        defaults = {
          lazy = false,
          version = false, -- always use the latest git commit
        },
        checker = { enabled = true }, -- automatically check for plugin updates
        performance = {
          rtp = {
            disabled_plugins = {
              "gzip",
              "tarPlugin",
              "tohtml",
              "tutor",
              "zipPlugin",
            },
          },
        },
      })
    '';
  };

  programs.helix = {
    enable = true;
    defaultEditor = false; # nvim is the default editor now; hx stays installed
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
