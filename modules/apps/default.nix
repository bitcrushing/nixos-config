# GUI apps that don't need a module of their own. Apps with substantial
# custom configuration get a sibling file (see vesktop.nix).
{ inputs, ... }:

{
  # Firefox manages its own profile; it follows the stylix GTK theme.
  programs.firefox.enable = true;

  # GVFS backends (trash://, mtp://, ...) for Nautilus.
  services.gvfs.enable = true;

  hm =
    { pkgs, ... }:
    {
      imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

      home.packages = with pkgs; [
        nautilus
        loupe # image viewer; image default set with xdg-mime (mimeapps.list is app-managed)
        papers # PDF viewer; PDF default set with xdg-mime
        decibels # audio player; audio default set with xdg-mime
        file-roller # archive manager (Nautilus "Extract here" / "Compress")
        ffmpegthumbnailer # video thumbnails in Nautilus
        libreoffice
        krita
        syncplay
        opencode
      ];

      # Official Spotify client patched by spicetify; stylix supplies the theme.
      programs.spicetify.enable = true;

      programs.mpv.enable = true;
      programs.obs-studio.enable = true;
    };
}
