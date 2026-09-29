# GUI apps that don't need a module of their own.
{ inputs, ... }:

{
  # Firefox manages its own profile; it follows the stylix GTK theme.
  programs.firefox.enable = true;

  # GVFS backends (trash://, mtp://, ...) for Nautilus.
  services.gvfs.enable = true;

  hm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Same opacity as ghostty (stylix.opacity.terminal in modules/theme.nix).
      glassPercent = toString (builtins.floor (config.stylix.opacity.terminal * 100 + 0.5));
    in
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
        qbittorrent
        syncplay
      ];

      # Official Spotify client patched by spicetify; stylix supplies the theme.
      programs.spicetify.enable = true;

      # Discord client with Vencord built in. stylix writes the theme to
      # ~/.config/vesktop/themes/stylix.css. Vencord's settings stay
      # app-managed (stylix would otherwise make them a read-only Nix file);
      # the activation step below only turns on the theme and window
      # transparency. Vesktop rewrites that file from memory, so the first
      # switch has to happen with it closed.
      programs.vesktop = {
        enable = true;
        vencord.settings = lib.mkForce { };
        # See-through window like ghostty: one tint on the app root, every
        # stacked panel transparent (stacked 80% layers would add up to
        # opaque). niri blurs the wallpaper behind it. Uses stylix's own
        # selector list: Discord nests several .theme-dark scopes, and each
        # gets stylix's opaque variables otherwise.
        vencord.themes.stylix = lib.mkAfter ''
          :root {
            --glass: color-mix(in srgb, var(--base00) ${glassPercent}%, transparent);
            --glass-panel: color-mix(in srgb, var(--base01) 35%, transparent);
          }
          html, body { background: transparent !important; }
          #app-mount { background: var(--glass) !important; }
          .theme-light, .theme-dark, .theme-darker, .theme-midnight, .visual-refresh {
            --__header-bar-background: transparent !important;
            --background-primary: transparent !important;
            --background-secondary: var(--glass-panel) !important;
            --background-secondary-alt: var(--glass-panel) !important;
            --background-tertiary: transparent !important;
            --background-base-lowest: transparent !important;
            --background-base-lower: transparent !important;
            --background-base-low: var(--glass-panel) !important;
            --background-base-tertiary: transparent !important;
            --home-background: transparent !important;
            --bg-base-primary: transparent !important;
            --bg-base-secondary: var(--glass-panel) !important;
            --bg-base-tertiary: transparent !important;
          }
          .visual-refresh {
            .bg__960e4, .wrapper_ef3116, .sidebar_c48ade, .members_c8ffbb, .member_c8ffbb,
            .chatContent_f75fb0, .chatGradient__36d07 { background: transparent !important; }
          }
        '';
      };
      home.activation.vesktopSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.writeShellScript "vesktop-settings" ''
          f="$HOME/.config/vesktop/settings/settings.json"
          mkdir -p "$(dirname "$f")"
          [ -s "$f" ] || echo '{}' > "$f"
          jq=${pkgs.jq}/bin/jq
          want='.transparent == true and ((.enabledThemes // []) | index("stylix.css") != null)'
          if ! "$jq" -e "$want" "$f" >/dev/null; then
            "$jq" '.transparent = true
              | .enabledThemes = ((.enabledThemes // []) - ["stylix.css"] + ["stylix.css"])' "$f" > "$f.tmp"
            mv "$f.tmp" "$f"
          fi
        ''}
      '';

      programs.mpv.enable = true;
      programs.obs-studio.enable = true;
    };
}
