{ config, pkgs, ... }:

{
  home.username = "bitcrushing";
  home.homeDirectory = "/home/bitcrushing";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "tokyo_night";
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
        space = {
          f = "file_picker";
          b = "buffer_picker";
          "/" = "global_search";
          y = ":clipboard-yank";
          p = ":clipboard-paste-after";
          P = ":clipboard-paste-before";
          s = ":spell-check";
          S = ":toggle-comments";
          "?" = "command_palette";
        };
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
