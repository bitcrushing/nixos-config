# Monet dusk theme — derived from twilight wallpaper (1689964585834142.jpg)
# Shared palette (hex):
#   bg #201d21  primary #2a2730  secondary #363342
#   accent #6886b0  accentHover #7a9bc8  accentPressed #465b77
#   fg #c8bcc8  fgMuted #756a85
#   keyword #9b7ba8  function #6886b0  string #7d9aa8  type #8ec5d8
#   variable #a88cae  numeric #c68890  comment #7c84a4
#   success #7d9aa8  warning #d4b07a  destructive #b57a82
#
# This is a NixOS module (imported by configuration.nix) so it can set
# system-level Firefox options. Home-manager settings are contributed
# via home-manager.users.bitcrushing and merge with home.nix.
{ config, lib, ... }:

{
  options.theme.palette = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {
      bg = "201d21";
      bgAlt = "2a2730";
      bgPanel = "363342";
      fg = "c8bcc8";
      fgBright = "ddd2da";
      fgMuted = "7c84a4";
      accent = "6886b0";
      accentHover = "7a9bc8";
      accentPressed = "465b77";
      border = "363342";
      keyword = "9b7ba8";
      string = "7d9aa8";
      type = "8ec5d8";
      variable = "a88cae";
      numeric = "c68890";
      destructive = "b57a82";
      warning = "d4b07a";
      success = "7d9aa8";
    };
    description = "Shared Monet dusk color palette";
  };

  config = {

  # ─── Firefox (NixOS-level) ────────────────────────────────────
  programs.firefox = {
    enable = true;
    preferences = {
      "browser.theme.content-theme" = 0;
      "browser.theme.toolbar-theme" = 0;
      "layout.css.prefers-color-scheme.content-override" = 0;
      "browser.in-content.dark-mode" = true;
      "ui.use_system_colors" = false;
      "browser.active_color" = "#6886b0";
      "browser.anchor_color" = "#6b9aae";
      "browser.visited_color" = "#9b7ba8";
      "browser.display.background_color" = "#201d21";
      "browser.display.foreground_color" = "#c8bcc8";
      "browser.display.use_document_colors" = false;
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    };
    autoConfig = ''
      var profDir = Services.dirsvc.get("ProfD", Components.interfaces.nsIFile);
      var chromeDir = profDir.clone();
      chromeDir.append("chrome");
      if (!chromeDir.exists()) chromeDir.create(Components.interfaces.nsIFile.DIRECTORY_TYPE, 493);
      var cssFile = chromeDir.clone();
      cssFile.append("userChrome.css");
      var lines = [
        ":root {",
        "  --monet-bg: #201d21;",
        "  --monet-bg-alt: #2a2730;",
        "  --monet-bg-panel: #363342;",
        "  --monet-fg: #c8bcc8;",
        "  --monet-fg-muted: #7c84a4;",
        "  --monet-accent: #6886b0;",
        "  --monet-accent-hover: #7a9bc8;",
        "  --monet-purple: #9b7ba8;",
        "  --monet-border: #363342;",
        "  --monet-rose: #b57a82;",
        "  --monet-teal: #7d9aa8;",
        "}",
        ":root, :root[lwtheme] {",
        "  --toolbar-bgcolor: var(--monet-bg-alt) !important;",
        "  --toolbar-color: var(--monet-fg) !important;",
        "  --toolbarbutton-icon-fill: var(--monet-fg) !important;",
        "  --toolbarbutton-hover-background: var(--monet-bg-panel) !important;",
        "  --toolbarbutton-active-background: var(--monet-bg-panel) !important;",
        "  --lwt-background-color: var(--monet-bg) !important;",
        "  --lwt-toolbarbutton-hover-background: var(--monet-bg-panel) !important;",
        "  --lwt-toolbarbutton-active-background: var(--monet-bg-panel) !important;",
        "  --lwt-text-color: var(--monet-fg) !important;",
        "  --lwt-accent-color: var(--monet-bg) !important;",
        "  --lwt-popup-bkgnd: var(--monet-bg-alt) !important;",
        "  --lwt-popup-color: var(--monet-fg) !important;",
        "  --lwt-popup-border-color: var(--monet-border) !important;",
        "  --arrowpanel-background: var(--monet-bg-alt) !important;",
        "  --arrowpanel-color: var(--monet-fg) !important;",
        "  --arrowpanel-border-color: var(--monet-border) !important;",
        "}",
        "#navigator-toolbox { background: var(--monet-bg) !important; }",
        "#nav-bar, #PersonalToolbar, #TabsToolbar {",
        "  background: var(--monet-bg-alt) !important;",
        "  color: var(--monet-fg) !important;",
        "}",
        ".tabbrowser-tab { background: var(--monet-bg) !important; color: var(--monet-fg-muted) !important; }",
        ".tabbrowser-tab[selected=\"true\"] { background: var(--monet-bg-alt) !important; color: var(--monet-fg) !important; }",
        ".tabbrowser-tab:hover:not([selected=\"true\"]) { background: var(--monet-bg-panel) !important; }",
        ".tab-line[selected=\"true\"] { background: var(--monet-accent) !important; }",
        "#urlbar { background: var(--monet-bg) !important; color: var(--monet-fg) !important; border: 1px solid var(--monet-border) !important; }",
        "#urlbar[focused=\"true\"] { border-color: var(--monet-accent) !important; }",
        "#urlbar-input, #urlbar-scheme { color: var(--monet-fg) !important; }",
        "#urlbar .urlbarView-row[selected], #urlbar .urlbarView-row:hover { background: var(--monet-bg-panel) !important; }",
        "#sidebar-box, #sidebar { background: var(--monet-bg) !important; color: var(--monet-fg) !important; }",
        "menupopup, panel { --panel-background: var(--monet-bg-alt) !important; --panel-color: var(--monet-fg) !important; }",
        "menu:hover, menuitem:hover { background: var(--monet-bg-panel) !important; color: var(--monet-fg) !important; }",
        "toolbarbutton { color: var(--monet-fg) !important; }",
        "toolbarseparator { border-color: var(--monet-border) !important; }",
        "#statuspanel { background: var(--monet-bg-alt) !important; color: var(--monet-fg) !important; }",
        ""
      ];
      var css = lines.join("\n");
      var fos = Components.classes["@mozilla.org/network/file-output-stream;1"].createInstance(Components.interfaces.nsIFileOutputStream);
      fos.init(cssFile, 0x02 | 0x08 | 0x20, 420, 0);
      fos.write(css, css.length);
      fos.close();
    '';
  };

  # ─── Wallpaper ───────────────────────────────────────────────
  # Stored in the nixos config dir; swaybg references the nix-store copy
  # directly via ${./wallpaper.jpg} in the Niri config below.

  # Custom desktop file: open text files in Ghostty → Helix
  home-manager.users.bitcrushing.xdg.dataFile."applications/Helix.desktop".text = ''
    [Desktop Entry]
    Name=Helix
    GenericName=Text Editor
    Comment=Edit text files in Ghostty
    Exec=ghostty -e hx %F
    Terminal=false
    Type=Application
    Icon=helix
    Categories=Utility;TextEditor;
    StartupNotify=false
    MimeType=text/plain;text/english;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;application/json;application/x-yaml;application/toml;application/x-toml;
  '';

  # Custom desktop file: open text files in Ghostty → Neovim (LazyVim)
  home-manager.users.bitcrushing.xdg.dataFile."applications/Neovim.desktop".text = ''
    [Desktop Entry]
    Name=Neovim
    GenericName=Text Editor
    Comment=Edit text files in Ghostty (LazyVim)
    Exec=ghostty -e nvim %F
    Terminal=false
    Type=Application
    Icon=nvim
    Categories=Utility;TextEditor;
    StartupNotify=false
    MimeType=text/plain;text/english;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;application/json;application/x-yaml;application/toml;application/x-toml;
  '';

  # ─── Home-manager theme settings ──────────────────────────────
  home-manager.users.bitcrushing = {
    # ── Bash prompt ──
    programs.bash.initExtra = ''
      PS1='\[\033[01;34m\]\u@\h:\w\[\033[00m\]\$ '
    '';

    # ── Ghostty terminal ──
    programs.ghostty.settings = {
      background = "201d21";
      foreground = "c8bcc8";
      cursor-color = "c8bcc8";
      selection-background = "363342";
      selection-foreground = "ddd2da";
      palette = [
        "0=#201d21"
        "1=#b57a82"
        "2=#7e9a6e"
        "3=#d4b07a"
        "4=#6886b0"
        "5=#9b7ba8"
        "6=#6b9aae"
        "7=#c8bcc8"
        "8=#7c84a4"
        "9=#c68890"
        "10=#8dae7c"
        "11=#e0c08c"
        "12=#7a9bc8"
        "13=#ae8fba"
        "14=#7daec2"
        "15=#ddd2da"
      ];
      background-opacity = "0.95";
      font-family = "AtkynsonMono Nerd Font Mono";
      font-size = 12;
      font-style = "Medium";
      # zero: slashed/dotted zero to distinguish 0 from O
      # case: case-sensitive punctuation forms for all-caps text
      font-feature = [ "zero" "case" ];
      cursor-style = "block";
      cursor-style-blink = false;
      window-title-font-family = "Atkinson Hyperlegible Next";
    };

    # ── GTK font — GUI apps on Niri use this ──
    gtk.font = {
      name = "Atkinson Hyperlegible Next";
      size = 12;
    };

    # ── Helix editor ──
    programs.helix.settings.theme = "monet_dusk";

    xdg.configFile."helix/themes/monet_dusk.toml".text = ''
      "ui.background" = { }
      "ui.virtual.whitespace" = "base03"
      "ui.virtual.jump-label" = { fg = "blue", modifiers = ["bold", "underlined"] }
      "ui.virtual.ruler" = { bg = "base01" }
      "ui.menu" = { fg = "base05", bg = "base01" }
      "ui.menu.selected" = { fg = "base01", bg = "base04" }
      "ui.linenr" = { fg = "base03" }
      "ui.popup" = { bg = "base01" }
      "ui.window" = { }
      "ui.linenr.selected" = { fg = "base04", modifiers = ["bold"] }
      "ui.selection" = { bg = "base02" }
      "comment" = { fg = "base03", modifiers = ["italic"] }
      "ui.statusline" = { fg = "base04", bg = "base01" }
      "ui.cursor" = { fg = "base04", modifiers = ["reversed"] }
      "ui.cursor.primary" = { fg = "base05", modifiers = ["reversed"] }
      "ui.text" = "base05"
      "operator" = "base05"
      "ui.text.focus" = "base05"
      "variable" = "base08"
      "constant.numeric" = "base09"
      "constant" = "base09"
      "attribute" = "base09"
      "type" = "base0A"
      "ui.cursor.match" = { fg = "base0A", modifiers = ["underlined"] }
      "string"  = "base0B"
      "variable.other.member" = "base05"
      "constant.character.escape" = "base0C"
      "function" = "base0D"
      "constructor" = "base0D"
      "special" = "base0D"
      "keyword" = "base0E"
      "label" = "base0E"
      "namespace" = "base0E"
      "ui.help" = { fg = "base06", bg = "base01" }

      "markup.heading" = "base0D"
      "markup.list" = "base08"
      "markup.bold" = { fg = "base0A", modifiers = ["bold"] }
      "markup.italic" = { fg = "base0E", modifiers = ["italic"] }
      "markup.strikethrough" = { modifiers = ["crossed_out"] }
      "markup.link.url" = { fg = "base09", modifiers = ["underlined"] }
      "markup.link.text" = "base08"
      "markup.quote" = "base0C"
      "markup.raw" = "base0B"

      "diff.plus" = "base0B"
      "diff.delta" = "base09"
      "diff.minus" = { fg = "#b57a82" }

      "diagnostic" = { modifiers = ["underlined"] }
      "ui.gutter" = { }
      "info" = "base0D"
      "hint" = "base03"
      "debug" = "base03"
      "warning" = "base09"
      "error" = { fg = "#b57a82" }

      "ui.bufferline" = { fg = "base04" }
      "ui.bufferline.active" = { fg = "base06", bg = "base01" }

      [palette]
      base00 = "#201d21"
      base01 = "#2a2730"
      base02 = "#363342"
      base03 = "#7c84a4"
      base04 = "#7c7488"
      base05 = "#c8bcc8"
      base06 = "#ddd2da"
      base07 = "#eee6ec"
      base08 = "#a88cae"
      base09 = "#c68890"
      base0A = "#8ec5d8"
      base0B = "#7d9aa8"
      base0C = "#6b9aae"
      base0D = "#6886b0"
      base0E = "#9b7ba8"
      base0F = "#8b6b5b"
    '';

    # ── opencode TUI ──
    xdg.configFile."opencode/opencode.jsonc".text = ''
      {
        "$schema": "https://opencode.ai/config.json"
      }
    '';

    xdg.configFile."opencode/tui.json".text = ''
      {
        "$schema": "https://opencode.ai/tui.json",
        "theme": "monet_dusk"
      }
    '';

    xdg.configFile."opencode/themes/monet_dusk.json".text = ''
      {
        "$schema": "https://opencode.ai/theme.json",
        "defs": {
          "bg": "#201d21",
          "bgPanel": "#2a2730",
          "bgElement": "#363342",
          "fg": "#c8bcc8",
          "fgMuted": "#756a85",
          "border": "#363342",
          "borderActive": "#544a5a",
          "duskBlue": "#6886b0",
          "mutedBlue": "#55667c",
          "twilightPurple": "#9b7ba8",
          "softMauve": "#a88cae",
          "mutedTeal": "#7d9aa8",
          "gold": "#c68890",
          "dustyRose": "#b57a82",
          "teal": "#6b9aae"
        },
        "theme": {
          "primary": { "dark": "duskBlue", "light": "duskBlue" },
          "secondary": { "dark": "mutedBlue", "light": "mutedBlue" },
          "accent": { "dark": "twilightPurple", "light": "twilightPurple" },
          "error": { "dark": "dustyRose", "light": "dustyRose" },
          "warning": { "dark": "duskBlue", "light": "duskBlue" },
          "success": { "dark": "mutedTeal", "light": "mutedTeal" },
          "info": { "dark": "teal", "light": "teal" },
          "text": { "dark": "fg", "light": "fg" },
          "textMuted": { "dark": "fgMuted", "light": "fgMuted" },
          "background": { "dark": "none", "light": "none" },
          "backgroundPanel": { "dark": "bgPanel", "light": "bgPanel" },
          "backgroundElement": { "dark": "bgElement", "light": "bgElement" },
          "border": { "dark": "border", "light": "border" },
          "borderActive": { "dark": "borderActive", "light": "borderActive" },
          "borderSubtle": { "dark": "border", "light": "border" },
          "diffAdded": { "dark": "mutedTeal", "light": "mutedTeal" },
          "diffRemoved": { "dark": "dustyRose", "light": "dustyRose" },
          "diffContext": { "dark": "fgMuted", "light": "fgMuted" },
          "diffHunkHeader": { "dark": "fgMuted", "light": "fgMuted" },
          "diffHighlightAdded": { "dark": "mutedTeal", "light": "mutedTeal" },
          "diffHighlightRemoved": { "dark": "dustyRose", "light": "dustyRose" },
          "diffAddedBg": { "dark": "bgPanel", "light": "bgPanel" },
          "diffRemovedBg": { "dark": "bgPanel", "light": "bgPanel" },
          "diffContextBg": { "dark": "bgPanel", "light": "bgPanel" },
          "diffLineNumber": { "dark": "fgMuted", "light": "fgMuted" },
          "diffAddedLineNumberBg": { "dark": "bgPanel", "light": "bgPanel" },
          "diffRemovedLineNumberBg": { "dark": "bgPanel", "light": "bgPanel" },
          "markdownText": { "dark": "fg", "light": "fg" },
          "markdownHeading": { "dark": "duskBlue", "light": "duskBlue" },
          "markdownLink": { "dark": "teal", "light": "teal" },
          "markdownLinkText": { "dark": "mutedTeal", "light": "mutedTeal" },
          "markdownCode": { "dark": "mutedTeal", "light": "mutedTeal" },
          "markdownBlockQuote": { "dark": "fgMuted", "light": "fgMuted" },
          "markdownEmph": { "dark": "twilightPurple", "light": "twilightPurple" },
          "markdownStrong": { "dark": "softMauve", "light": "softMauve" },
          "markdownHorizontalRule": { "dark": "fgMuted", "light": "fgMuted" },
          "markdownListItem": { "dark": "duskBlue", "light": "duskBlue" },
          "markdownListEnumeration": { "dark": "mutedTeal", "light": "mutedTeal" },
          "markdownImage": { "dark": "teal", "light": "teal" },
          "markdownImageText": { "dark": "mutedTeal", "light": "mutedTeal" },
          "markdownCodeBlock": { "dark": "fg", "light": "fg" },
          "syntaxComment": { "dark": "fgMuted", "light": "fgMuted" },
          "syntaxKeyword": { "dark": "twilightPurple", "light": "twilightPurple" },
          "syntaxFunction": { "dark": "duskBlue", "light": "duskBlue" },
          "syntaxVariable": { "dark": "softMauve", "light": "softMauve" },
          "syntaxString": { "dark": "mutedTeal", "light": "mutedTeal" },
          "syntaxNumber": { "dark": "gold", "light": "gold" },
          "syntaxType": { "dark": "teal", "light": "teal" },
          "syntaxOperator": { "dark": "fg", "light": "fg" },
          "syntaxPunctuation": { "dark": "fg", "light": "fg" }
        }
      }
    '';

    # ── Neovim (LazyVim) colorscheme ──
    # Same palette mapping as Helix/opencode. Normal has no bg so Ghostty
    # transparency shows through. Types use muted teal (bright #8ec5d8 was
    # retired). home.nix sets LazyVim opts.colorscheme = "monet_dusk".
    xdg.configFile."nvim/colors/monet_dusk.lua".text = ''
      -- monet_dusk — derived from twilight wallpaper; see theme.nix for palette
      local c = {
        bg         = "#201d21",
        bg_panel   = "#2a2730",
        bg_element = "#363342",
        fg         = "#c8bcc8",
        fg_bright  = "#ddd2da",
        fg_muted   = "#756a85",
        comment    = "#7c84a4",
        blue       = "#6886b0",
        blue_hover = "#7a9bc8",
        muted_blue = "#55667c",
        purple     = "#9b7ba8",
        mauve      = "#a88cae",
        teal       = "#6b9aae",
        muted_teal = "#7d9aa8",
        gold       = "#c68890",
        warning    = "#d4b07a",
        rose       = "#b57a82",
      }

      vim.cmd("hi clear")
      if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
      end
      vim.o.background = "dark"
      vim.g.colors_name = "monet_dusk"

      local function hi(group, opts)
        vim.api.nvim_set_hl(0, group, opts)
      end

      -- ── Editor chrome ──
      hi("Normal", { fg = c.fg }) -- no bg: terminal transparency
      hi("NormalNC", { fg = c.fg })
      hi("NormalFloat", { fg = c.fg, bg = c.bg_panel })
      hi("FloatBorder", { fg = c.bg_element, bg = c.bg_panel })
      hi("FloatTitle", { fg = c.purple, bg = c.bg_panel })
      hi("FloatFooter", { fg = c.fg_muted, bg = c.bg_panel })
      hi("Cursor", { reverse = true })
      hi("CursorLine", { bg = c.bg_panel })
      hi("CursorColumn", { bg = c.bg_panel })
      hi("ColorColumn", { bg = c.bg_panel })
      hi("LineNr", { fg = c.comment })
      hi("CursorLineNr", { fg = c.fg_bright, bold = true })
      hi("SignColumn", {})
      hi("StatusLine", { fg = c.comment, bg = c.bg_panel })
      hi("StatusLineNC", { fg = c.fg_muted, bg = c.bg_panel })
      hi("WinSeparator", { fg = c.bg_element })
      hi("VertSplit", { link = "WinSeparator" })
      hi("Visual", { bg = c.bg_element })
      hi("VisualNOS", { bg = c.bg_element })
      hi("Search", { fg = c.bg, bg = c.blue })
      hi("IncSearch", { fg = c.bg, bg = c.purple })
      hi("CurSearch", { link = "IncSearch" })
      hi("Substitute", { fg = c.bg, bg = c.rose })
      hi("Pmenu", { fg = c.fg, bg = c.bg_panel })
      hi("PmenuSel", { fg = c.bg_panel, bg = c.comment })
      hi("PmenuSbar", { bg = c.bg_panel })
      hi("PmenuThumb", { bg = c.bg_element })
      hi("PmenuKind", { fg = c.purple, bg = c.bg_panel })
      hi("PmenuExtra", { fg = c.fg_muted, bg = c.bg_panel })
      hi("Directory", { fg = c.blue })
      hi("Title", { fg = c.purple, bold = true })
      hi("Question", { fg = c.teal })
      hi("MoreMsg", { fg = c.teal })
      hi("ModeMsg", { fg = c.fg })
      hi("ErrorMsg", { fg = c.rose })
      hi("WarningMsg", { fg = c.warning })
      hi("NonText", { fg = c.bg_element })
      hi("EndOfBuffer", { link = "NonText" })
      hi("Whitespace", { fg = c.comment })
      hi("SpecialKey", { fg = c.comment })
      hi("Conceal", { fg = c.fg_muted })
      hi("MatchParen", { fg = c.teal, underline = true })
      hi("Folded", { fg = c.fg_muted, bg = c.bg_panel })
      hi("FoldColumn", { fg = c.fg_muted })
      hi("QuickFixLine", { bg = c.bg_element })
      hi("WildMenu", { link = "PmenuSel" })
      hi("WinBar", { fg = c.comment, bg = c.bg_panel })
      hi("WinBarNC", { fg = c.fg_muted, bg = c.bg_panel })
      hi("TabLine", { fg = c.comment, bg = c.bg_panel })
      hi("TabLineSel", { fg = c.fg_bright, bg = c.bg_element })
      hi("TabLineFill", { bg = c.bg_panel })
      hi("SpellBad", { sp = c.rose, undercurl = true })
      hi("SpellCap", { sp = c.warning, undercurl = true })
      hi("SpellRare", { sp = c.purple, undercurl = true })
      hi("SpellLocal", { sp = c.teal, undercurl = true })

      -- ── Legacy syntax ──
      hi("Comment", { fg = c.comment, italic = true })
      hi("Constant", { fg = c.gold })
      hi("String", { fg = c.muted_teal })
      hi("Character", { fg = c.muted_teal })
      hi("Number", { fg = c.gold })
      hi("Float", { fg = c.gold })
      hi("Boolean", { fg = c.gold })
      hi("Identifier", { fg = c.mauve })
      hi("Function", { fg = c.blue })
      hi("Statement", { fg = c.purple })
      hi("Keyword", { fg = c.purple })
      hi("Conditional", { fg = c.purple })
      hi("Repeat", { fg = c.purple })
      hi("Label", { fg = c.purple })
      hi("Operator", { fg = c.fg })
      hi("Exception", { fg = c.rose })
      hi("PreProc", { fg = c.purple })
      hi("Type", { fg = c.teal })
      hi("StorageClass", { fg = c.teal })
      hi("Structure", { fg = c.teal })
      hi("Typedef", { fg = c.teal })
      hi("Special", { fg = c.blue })
      hi("SpecialChar", { fg = c.teal })
      hi("Tag", { fg = c.purple })
      hi("Delimiter", { fg = c.fg })
      hi("Underlined", { fg = c.gold, underline = true })
      hi("Error", { fg = c.rose })
      hi("Todo", { fg = c.blue, bold = true })

      -- ── Treesitter ──
      hi("@variable", { fg = c.mauve })
      hi("@variable.builtin", { fg = c.rose })
      hi("@variable.member", { fg = c.fg })
      hi("@variable.parameter", { fg = c.mauve })
      hi("@constant", { fg = c.gold })
      hi("@constant.builtin", { fg = c.gold })
      hi("@string", { fg = c.muted_teal })
      hi("@string.escape", { fg = c.teal })
      hi("@character", { fg = c.muted_teal })
      hi("@number", { fg = c.gold })
      hi("@boolean", { fg = c.gold })
      hi("@float", { fg = c.gold })
      hi("@function", { fg = c.blue })
      hi("@function.call", { fg = c.blue })
      hi("@function.method", { fg = c.blue })
      hi("@function.builtin", { fg = c.rose })
      hi("@constructor", { fg = c.blue })
      hi("@keyword", { fg = c.purple })
      hi("@keyword.function", { fg = c.purple })
      hi("@keyword.return", { fg = c.purple })
      hi("@keyword.conditional", { fg = c.purple })
      hi("@keyword.repeat", { fg = c.purple })
      hi("@keyword.operator", { fg = c.fg })
      hi("@type", { fg = c.teal })
      hi("@type.builtin", { fg = c.teal })
      hi("@property", { fg = c.fg })
      hi("@namespace", { fg = c.purple })
      hi("@module", { fg = c.purple })
      hi("@operator", { fg = c.fg })
      hi("@punctuation", { fg = c.fg })
      hi("@punctuation.bracket", { fg = c.fg })
      hi("@punctuation.delimiter", { fg = c.fg })
      hi("@comment", { fg = c.comment, italic = true })
      hi("@tag", { fg = c.purple })
      hi("@tag.attribute", { fg = c.purple })
      hi("@tag.delimiter", { fg = c.fg })
      -- markup (matches opencode markdown roles)
      hi("@markup.heading", { fg = c.blue, bold = true })
      hi("@markup.strong", { fg = c.mauve, bold = true })
      hi("@markup.italic", { fg = c.purple, italic = true })
      hi("@markup.strikethrough", { strikethrough = true })
      hi("@markup.link", { fg = c.teal, underline = true })
      hi("@markup.link.url", { fg = c.gold, underline = true })
      hi("@markup.raw", { fg = c.muted_teal })
      hi("@markup.quote", { fg = c.teal })
      hi("@markup.list", { fg = c.mauve })
      hi("@diff.plus", { fg = c.muted_teal })
      hi("@diff.minus", { fg = c.rose })
      hi("@diff.delta", { fg = c.gold })

      -- ── Diagnostics ──
      hi("DiagnosticError", { fg = c.rose })
      hi("DiagnosticWarn", { fg = c.warning })
      hi("DiagnosticInfo", { fg = c.blue })
      hi("DiagnosticHint", { fg = c.comment })
      hi("DiagnosticOk", { fg = c.muted_teal })
      hi("DiagnosticUnderlineError", { sp = c.rose, undercurl = true })
      hi("DiagnosticUnderlineWarn", { sp = c.warning, undercurl = true })
      hi("DiagnosticUnderlineInfo", { sp = c.blue, undercurl = true })
      hi("DiagnosticUnderlineHint", { sp = c.comment, undercurl = true })
      hi("DiagnosticVirtualTextError", { fg = c.rose, bg = c.bg_panel })
      hi("DiagnosticVirtualTextWarn", { fg = c.warning, bg = c.bg_panel })
      hi("DiagnosticVirtualTextInfo", { fg = c.blue, bg = c.bg_panel })
      hi("DiagnosticVirtualTextHint", { fg = c.comment, bg = c.bg_panel })

      -- ── Git / diff ──
      hi("DiffAdd", { fg = c.muted_teal, bg = c.bg_panel })
      hi("DiffDelete", { fg = c.rose, bg = c.bg_panel })
      hi("DiffChange", { fg = c.gold, bg = c.bg_panel })
      hi("DiffText", { fg = c.fg_bright, bg = c.bg_element })
      hi("Added", { fg = c.muted_teal })
      hi("Removed", { fg = c.rose })
      hi("Changed", { fg = c.gold })
      hi("GitSignsAdd", { fg = c.muted_teal })
      hi("GitSignsChange", { fg = c.gold })
      hi("GitSignsDelete", { fg = c.rose })

      -- ── Plugin groups (LazyVim defaults) ──
      hi("WhichKey", { fg = c.purple })
      hi("WhichKeyDesc", { fg = c.fg })
      hi("WhichKeyGroup", { fg = c.blue })
      hi("WhichKeySeparator", { fg = c.fg_muted })
      hi("IblIndent", { fg = c.bg_panel })
      hi("IblScope", { fg = c.muted_blue })
      hi("NeoTreeDirectoryName", { fg = c.blue })
      hi("NeoTreeDirectoryIcon", { fg = c.blue })
      hi("NeoTreeFileName", { fg = c.fg })
      hi("NeoTreeGitAdded", { fg = c.muted_teal })
      hi("NeoTreeGitModified", { fg = c.gold })
      hi("NeoTreeGitDeleted", { fg = c.rose })
      hi("NotifyERRORBorder", { fg = c.rose })
      hi("NotifyWARNBorder", { fg = c.warning })
      hi("NotifyINFOBorder", { fg = c.blue })
      hi("NotifyERRORTitle", { fg = c.rose })
      hi("NotifyWARNTitle", { fg = c.warning })
      hi("NotifyINFOTitle", { fg = c.blue })
      hi("TelescopeNormal", { fg = c.fg, bg = c.bg_panel })
      hi("TelescopeBorder", { fg = c.bg_element, bg = c.bg_panel })
      hi("TelescopeSelection", { bg = c.bg_element })
      hi("TelescopeMatching", { fg = c.purple, bold = true })
    '';

    # ── spotify-player ──
    # No palette.background → terminal transparency shows through.
    # app.toml (managed manually) must set theme = "monet_dusk".
    xdg.configFile."spotify-player/theme.toml".text = ''
      [[themes]]
      name = "monet_dusk"

      [themes.palette]
      foreground = "#c8bcc8"

      [themes.component_style.block_title]
      fg = "#9b7ba8"
      modifiers = ["Bold"]

      [themes.component_style.border]
      fg = "#363342"

      [themes.component_style.playback_status]
      fg = "#6886b0"
      modifiers = ["Bold"]

      [themes.component_style.playback_track]
      fg = "#ddd2da"
      modifiers = ["Bold"]

      [themes.component_style.playback_artists]
      fg = "#6886b0"
      modifiers = ["Bold"]

      [themes.component_style.playback_album]
      fg = "#a88cae"

      [themes.component_style.playback_genres]
      fg = "#7c84a4"
      modifiers = ["Italic"]

      [themes.component_style.playback_metadata]
      fg = "#7c84a4"

      [themes.component_style.playback_progress_bar]
      fg = "#6886b0"
      bg = "#363342"

      [themes.component_style.playback_progress_bar_unfilled]
      bg = "#363342"

      [themes.component_style.current_playing]
      fg = "#7d9aa8"
      modifiers = ["Bold"]

      [themes.component_style.page_desc]
      fg = "#7a9bc8"
      modifiers = ["Bold"]

      [themes.component_style.playlist_desc]
      fg = "#756a85"
      modifiers = ["Dim"]

      [themes.component_style.table_header]
      fg = "#9b7ba8"

      [themes.component_style.selection]
      modifiers = ["Bold", "Reversed"]

      [themes.component_style.like]
      fg = "#b57a82"

      [themes.component_style.lyrics_playing]
      fg = "#7a9bc8"
      modifiers = ["Bold"]
    '';

  };
};
}
