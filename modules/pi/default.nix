# pi coding agent: package, settings, stylix-coloured theme, extensions.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  bases = map (n: "base0${n}") [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "A"
    "B"
    "C"
    "D"
    "E"
    "F"
  ];
  palette = lib.genAttrs bases (b: config.lib.stylix.colors.withHashtag.${b});
in
{
  hm = {
    home.packages = with pkgs; [
      pi-coding-agent
      nodejs # pi installs the npm: packages below with npm
      # node-gyp fallback for extensions with native modules
      # (e.g. pi-hermes-memory's better-sqlite3); gcc is in tooling.nix.
      python3
      gnumake
    ];

    # Nix-managed and read-only: change settings here, not via pi's /settings.
    # Missing packages are installed on startup; update them with
    # `pi update --extensions`.
    home.file.".pi/agent/settings.json".text = builtins.toJSON {
      theme = "stylix";
      # Pi owns the viewport and only draws what's visible, so resizing stays
      # smooth in long conversations (regular mode reprints the whole
      # transcript into Ghostty's scrollback on every width change).
      tuiMode = "fullscreen";
      # No defaultModel: extensions/last-model.ts restores the last one used.
      defaultProvider = "opencode";
      packages = [
        "npm:pi-web-access"
        "npm:@plannotator/pi-extension"
        "npm:@juicesharp/rpiv-todo"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:pi-hermes-memory"
        "npm:pi-subagents"
      ];
    };

    # Loaded from ~/.pi/agent/extensions/. Node builtins only, so they run
    # straight from the store.
    home.file.".pi/agent/extensions/last-model.ts".source = ./extensions/last-model.ts;
    home.file.".pi/agent/extensions/notify-mako.ts".source = ./extensions/notify-mako.ts;

    # Theme vars are the base16 palette; roles follow base16 conventions
    # (08 red/errors, 0A yellow/types, 0B green/strings, 0D blue/functions,
    # 0E purple/keywords).
    home.file.".pi/agent/themes/stylix.json".text = builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
      name = "stylix";
      vars = palette;
      colors = {
        accent = "base0D";
        border = "base0D";
        borderAccent = "base0C";
        borderMuted = "base02";
        success = "base0B";
        error = "base08";
        warning = "base0A";
        muted = "base04";
        dim = "base03";
        text = "base05";
        thinkingText = "base04";

        selectedBg = "base02";
        scrollbarTrack = "base02";
        scrollbarThumb = "base04";
        searchMatchBg = "base02";
        searchMatchText = "base05";
        userMessageBg = "base01";
        userMessageText = "base05";
        customMessageBg = "base01";
        customMessageText = "base05";
        customMessageLabel = "base0E";
        toolPendingBg = "base01";
        toolSuccessBg = "base01";
        toolErrorBg = "base01";
        toolTitle = "base05";
        toolOutput = "base04";

        mdHeading = "base0D";
        mdLink = "base0C";
        mdLinkUrl = "base04";
        mdCode = "base0B";
        mdCodeBlock = "base05";
        mdCodeBlockBorder = "base02";
        mdQuote = "base04";
        mdQuoteBorder = "base02";
        mdHr = "base02";
        mdListBullet = "base0D";

        toolDiffAdded = "base0B";
        toolDiffRemoved = "base08";
        toolDiffContext = "base04";

        syntaxComment = "base03";
        syntaxKeyword = "base0E";
        syntaxFunction = "base0D";
        syntaxVariable = "base08";
        syntaxString = "base0B";
        syntaxNumber = "base09";
        syntaxType = "base0A";
        syntaxOperator = "base05";
        syntaxPunctuation = "base05";

        # Also colours the input box border. Cool to warm through the scheme's
        # accents (Rosé Pine Moon: pine, foam, iris, gold, love). Picked by
        # hue, not base16 role: in this port base0E (keywords) is gold.
        thinkingOff = "base02";
        thinkingMinimal = "base03";
        thinkingLow = "base0B"; # pine
        thinkingMedium = "base0C"; # foam
        thinkingHigh = "base0D"; # iris
        thinkingXhigh = "base09"; # gold
        thinkingMax = "base08"; # love

        bashMode = "base0B";
      };
      export = {
        pageBg = palette.base00;
        cardBg = palette.base01;
        infoBg = palette.base02;
      };
    };
  };
}
