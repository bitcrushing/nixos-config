# Ghostty terminal. Colours, opacity and the font family/size come from
# stylix (modules/theme.nix); this file adds glyph fallbacks, a background
# shader and terminal behaviour.
{
  config,
  lib,
  ...
}:

{
  hm.programs.ghostty = {
    enable = true;
    settings = {
      # Fira Mono is the stylix monospace; Symbols fills the Nerd glyphs
      # it doesn't ship, then stylix's emoji font.
      font-family = lib.mkForce [
        config.stylix.fonts.monospace.name
        "Symbols Nerd Font Mono"
        config.stylix.fonts.emoji.name
      ];
      # mkForce: stylix also writes font-size from fonts.sizes.terminal.
      font-size = lib.mkForce config.stylix.fonts.sizes.terminal;

      cursor-style = "block";
      cursor-style-blink = false;
      scrollbar = "never"; # scrolling still works
      # Apply background-opacity to cells with their own background colour
      # too (pi's panels, nvim floats), not just the default background.
      background-opacity-cells = true;
      window-title-font-family = config.stylix.fonts.sansSerif.name;

      # A slow caustic wash, tinted from the live palette. It only touches
      # background pixels and preserves the window alpha. See
      # ghostty/moonwater.glsl for the strength and speed knobs.
      custom-shader = "${./ghostty/moonwater.glsl}";
      custom-shader-animation = true;
    };
  };
}
