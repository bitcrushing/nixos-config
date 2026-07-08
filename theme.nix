# Monet dusk theme — derived from Monet twilight wallpaper (1689964585834142.jpg)
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
{ ... }:

{
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

  # ─── Wallpaper (COSMIC background) ────────────────────────────
  # The wallpaper is stored in the nixos config directory for portability.
  # It is symlinked into ~/Downloads by home-manager so COSMIC can read it.
  home-manager.users.bitcrushing.home.file."Downloads/wallpaper.jpg".source = ./wallpaper.jpg;

  # Custom desktop file so COSMIC opens text files in Ghostty → Helix
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

  home-manager.users.bitcrushing.xdg.configFile."cosmic/com.system76.CosmicBackground/v1/all".text = ''
    (
        output: "all",
        source: Path("/home/bitcrushing/Downloads/wallpaper.jpg"),
        filter_by_theme: false,
        rotation_frequency: 300,
        filter_method: Lanczos,
        scaling_mode: Zoom,
        sampling_method: Alphanumeric,
    )
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
      font-family = "VictorMono Nerd Font Mono";
      font-size = 13;
      font-style = "Medium";
      cursor-style = "block";
      cursor-style-blink = false;
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
          "goldenHour": "#8ec5d8",
          "gold": "#c68890",
          "dustyRose": "#b57a82",
          "teal": "#6b9aae"
        },
        "theme": {
          "primary": { "dark": "duskBlue", "light": "duskBlue" },
          "secondary": { "dark": "mutedBlue", "light": "mutedBlue" },
          "accent": { "dark": "twilightPurple", "light": "twilightPurple" },
          "error": { "dark": "dustyRose", "light": "dustyRose" },
          "warning": { "dark": "goldenHour", "light": "goldenHour" },
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
          "markdownStrong": { "dark": "goldenHour", "light": "goldenHour" },
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
          "syntaxType": { "dark": "goldenHour", "light": "goldenHour" },
          "syntaxOperator": { "dark": "fg", "light": "fg" },
          "syntaxPunctuation": { "dark": "fg", "light": "fg" }
        }
      }
    '';

    # ── Fontconfig — make VictorMono the system default ──
    # cosmic-comp (window title bars) uses fontconfig's default sans-serif,
    # not the CosmicTk interface_font. This ensures title bars match.
    xdg.configFile."fontconfig/conf.d/99-victormono-default.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="pattern">
          <test name="family"><string>sans-serif</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>VictorMono Nerd Font</string>
          </edit>
        </match>
        <match target="pattern">
          <test name="family"><string>serif</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>VictorMono Nerd Font</string>
          </edit>
        </match>
        <match target="pattern">
          <test name="family"><string>monospace</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>VictorMono Nerd Font Mono</string>
          </edit>
        </match>
      </fontconfig>
    '';

    # ── COSMIC DE — dark theme + frosted glass + GUI font ──
    xdg.configFile."cosmic/com.system76.CosmicTk/v1/interface_font".text = ''
      (
          family: "VictorMono Nerd Font",
          weight: Medium,
          stretch: Normal,
          style: Normal,
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/name".text = ''"monet_dusk"'';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/is_dark".text = "true";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/is_frosted".text = "true";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/is_high_contrast".text = "false";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/active_hint".text = "3";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/text_tint".text = "None";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/control_tint".text = "None";
    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/window_hint".text = ''
      Some((red: 0.30, green: 0.36, blue: 0.46, alpha: 1.0))
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/corner_radii".text = ''
      (
          radius_0: (0.0, 0.0, 0.0, 0.0),
          radius_xs: (2.0, 2.0, 2.0, 2.0),
          radius_s: (8.0, 8.0, 8.0, 8.0),
          radius_m: (8.0, 8.0, 8.0, 8.0),
          radius_l: (8.0, 8.0, 8.0, 8.0),
          radius_xl: (8.0, 8.0, 8.0, 8.0),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/gaps".text = "(0, 8)";

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/spacing".text = ''
      (
          space_none: 0,
          space_xxxs: 4,
          space_xxs: 4,
          space_xs: 8,
          space_s: 8,
          space_m: 16,
          space_l: 24,
          space_xl: 32,
          space_xxl: 48,
          space_xxxl: 64,
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/shade".text = ''
      (
          red: 0.0,
          green: 0.0,
          blue: 0.0,
          alpha: 0.32,
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/accent".text = ''
      (
          base: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          hover: (red: 0.592, green: 0.537, blue: 0.639, alpha: 1.0),
          pressed: (red: 0.420, green: 0.380, blue: 0.463, alpha: 1.0),
          selected: (red: 0.592, green: 0.537, blue: 0.639, alpha: 1.0),
          selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          divider: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          on: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          disabled: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          on_disabled: (red: 0.261, green: 0.238, blue: 0.286, alpha: 1.0),
          border: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          disabled_border: (red: 0.522, green: 0.475, blue: 0.573, alpha: 0.5),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/accent_button".text = ''
      (
          base: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          hover: (red: 0.592, green: 0.537, blue: 0.639, alpha: 1.0),
          pressed: (red: 0.420, green: 0.380, blue: 0.463, alpha: 1.0),
          selected: (red: 0.592, green: 0.537, blue: 0.639, alpha: 1.0),
          selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          divider: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          on: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          disabled: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          on_disabled: (red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5),
          border: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          disabled_border: (red: 0.522, green: 0.475, blue: 0.573, alpha: 0.5),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/accent_text".text = ''
      Some((red: 0.592, green: 0.537, blue: 0.639, alpha: 1.0))
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/background".text = ''
      (
          base: (red: 0.125, green: 0.114, blue: 0.129, alpha: 0.95),
          component: (
              base: (red: 0.165, green: 0.153, blue: 0.188, alpha: 1.0),
              hover: (red: 0.212, green: 0.200, blue: 0.259, alpha: 1.0),
              pressed: (red: 0.259, green: 0.247, blue: 0.329, alpha: 1.0),
              selected: (red: 0.212, green: 0.200, blue: 0.259, alpha: 1.0),
              selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              divider: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.2),
              on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled: (red: 0.165, green: 0.153, blue: 0.188, alpha: 0.5),
              on_disabled: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.65),
              border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled_border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.5),
          ),
          divider: (red: 0.212, green: 0.200, blue: 0.259, alpha: 1.0),
          on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
          small_widget: (red: 0.145, green: 0.133, blue: 0.165, alpha: 0.25),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/primary".text = ''
      (
          base: (red: 0.165, green: 0.153, blue: 0.188, alpha: 0.95),
          component: (
              base: (red: 0.212, green: 0.200, blue: 0.259, alpha: 1.0),
              hover: (red: 0.259, green: 0.247, blue: 0.329, alpha: 1.0),
              pressed: (red: 0.306, green: 0.294, blue: 0.392, alpha: 1.0),
              selected: (red: 0.259, green: 0.247, blue: 0.329, alpha: 1.0),
              selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              divider: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.2),
              on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled: (red: 0.212, green: 0.200, blue: 0.259, alpha: 0.5),
              on_disabled: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.65),
              border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled_border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.5),
          ),
          divider: (red: 0.259, green: 0.247, blue: 0.329, alpha: 1.0),
          on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
          small_widget: (red: 0.188, green: 0.176, blue: 0.231, alpha: 0.25),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/secondary".text = ''
      (
          base: (red: 0.212, green: 0.200, blue: 0.259, alpha: 1.0),
          component: (
              base: (red: 0.239, green: 0.227, blue: 0.294, alpha: 1.0),
              hover: (red: 0.286, green: 0.275, blue: 0.357, alpha: 1.0),
              pressed: (red: 0.333, green: 0.322, blue: 0.420, alpha: 1.0),
              selected: (red: 0.286, green: 0.275, blue: 0.357, alpha: 1.0),
              selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
              divider: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.2),
              on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled: (red: 0.239, green: 0.227, blue: 0.294, alpha: 0.5),
              on_disabled: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.65),
              border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
              disabled_border: (red: 0.784, green: 0.737, blue: 0.784, alpha: 0.5),
          ),
          divider: (red: 0.286, green: 0.275, blue: 0.357, alpha: 1.0),
          on: (red: 0.784, green: 0.737, blue: 0.784, alpha: 1.0),
          small_widget: (red: 0.259, green: 0.247, blue: 0.329, alpha: 0.25),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/success".text = ''
      (
          base: (red: 0.490, green: 0.604, blue: 0.659, alpha: 1.0),
          hover: (red: 0.435, green: 0.537, blue: 0.586, alpha: 1.0),
          pressed: (red: 0.267, green: 0.329, blue: 0.359, alpha: 1.0),
          selected: (red: 0.435, green: 0.537, blue: 0.586, alpha: 1.0),
          selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          divider: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          on: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          disabled: (red: 0.490, green: 0.604, blue: 0.659, alpha: 1.0),
          on_disabled: (red: 0.245, green: 0.302, blue: 0.330, alpha: 1.0),
          border: (red: 0.490, green: 0.604, blue: 0.659, alpha: 1.0),
          disabled_border: (red: 0.490, green: 0.604, blue: 0.659, alpha: 0.5),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/warning".text = ''
      (
          base: (red: 0.831, green: 0.690, blue: 0.478, alpha: 1.0),
          hover: (red: 0.729, green: 0.606, blue: 0.420, alpha: 1.0),
          pressed: (red: 0.451, green: 0.375, blue: 0.260, alpha: 1.0),
          selected: (red: 0.729, green: 0.606, blue: 0.420, alpha: 1.0),
          selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          divider: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          on: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          disabled: (red: 0.831, green: 0.690, blue: 0.478, alpha: 1.0),
          on_disabled: (red: 0.416, green: 0.345, blue: 0.239, alpha: 1.0),
          border: (red: 0.831, green: 0.690, blue: 0.478, alpha: 1.0),
          disabled_border: (red: 0.831, green: 0.690, blue: 0.478, alpha: 0.5),
      )
    '';

    xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/destructive".text = ''
      (
          base: (red: 0.710, green: 0.478, blue: 0.510, alpha: 1.0),
          hover: (red: 0.624, green: 0.420, blue: 0.448, alpha: 1.0),
          pressed: (red: 0.385, green: 0.260, blue: 0.277, alpha: 1.0),
          selected: (red: 0.624, green: 0.420, blue: 0.448, alpha: 1.0),
          selected_text: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          focus: (red: 0.522, green: 0.475, blue: 0.573, alpha: 1.0),
          divider: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          on: (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
          disabled: (red: 0.710, green: 0.478, blue: 0.510, alpha: 1.0),
          on_disabled: (red: 0.355, green: 0.239, blue: 0.255, alpha: 1.0),
          border: (red: 0.710, green: 0.478, blue: 0.510, alpha: 1.0),
          disabled_border: (red: 0.710, green: 0.478, blue: 0.510, alpha: 0.5),
      )
    '';
  };
}
