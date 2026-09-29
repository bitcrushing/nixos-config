# Neovim with LazyVim. The config is ./neovim/init.lua; plugins are
# installed by lazy.nvim at runtime, not by Nix.
{ ... }:

{
  hm = {
    programs.neovim = {
      enable = true;
      defaultEditor = true; # sets EDITOR
      viAlias = true;
      vimAlias = true;
      initLua = builtins.readFile ./neovim/init.lua;
    };

    xdg.desktopEntries.Neovim = {
      name = "Neovim";
      genericName = "Text Editor";
      comment = "Edit text files in Ghostty";
      exec = "ghostty -e nvim %F";
      terminal = false;
      icon = "nvim";
      categories = [
        "Utility"
        "TextEditor"
      ];
      startupNotify = false;
      mimeType = [
        "text/plain"
        "text/english"
        "text/x-makefile"
        "text/x-c++hdr"
        "text/x-c++src"
        "text/x-chdr"
        "text/x-csrc"
        "text/x-java"
        "text/x-moc"
        "text/x-pascal"
        "text/x-tcl"
        "text/x-tex"
        "application/x-shellscript"
        "text/x-c"
        "text/x-c++"
        "application/json"
        "application/x-yaml"
        "application/toml"
        "application/x-toml"
      ];
    };
  };
}
