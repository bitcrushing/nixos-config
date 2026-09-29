# Language servers, formatters and dev tools for Neovim. LSPs are
# installed here rather than through mason, which can't work on NixOS
# without npm.
{ pkgs, ... }:

{
  hm.home.packages = with pkgs; [
    devenv

    # LazyVim runtime requirements
    gcc # compiles tree-sitter parsers
    tree-sitter
    ripgrep # grep pickers
    fd # file pickers
    lazygit

    # LSPs and formatters
    nil # Nix
    nixfmt
    bash-language-server
    rust-analyzer
    ruff # Python lint + format
    typescript-language-server
    prettier
    vscode-langservers-extracted # JSON/HTML/CSS
    taplo # TOML
    yaml-language-server
    marksman # Markdown
  ];
}
