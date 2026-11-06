# Shared look of the desktop: niri windows plus the Noctalia shell.
# Colours are base16 slot names; resolve them with config.lib.stylix.colors
# (e.g. `colors.withHashtag.${style.border.focused}`).
{
  gaps = 8;
  border = {
    width = 1;
    # base0F: in Rosé Pine Moon the "highlight high" grey-lavender (#56526e),
    # halfway between unfocused (base02) and base03. Subtle on the dark wallpaper;
    # the accent (base0D) is far too loud for a border.
    focused = "base0F";
    unfocused = "base02";
  };
}
