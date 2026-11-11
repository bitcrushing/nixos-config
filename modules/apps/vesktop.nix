# Vesktop (Discord) with Vencord, themed by stylix.
{ ... }:

{
  hm =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Discord client with Vencord built in. stylix writes the Rosé Pine Moon
      # theme to ~/.config/vesktop/themes/stylix.css. Vencord's settings stay
      # app-managed (stylix would otherwise make them a read-only Nix file);
      # the activation step below only enables the theme and keeps Vencord's
      # own window transparency off. Vesktop rewrites that file from memory,
      # so the first switch has to happen with it closed.
      programs.vesktop = {
        enable = true;
        vencord.settings = lib.mkForce { };
      };
      # mkForce: home-manager's vesktop module defines this same step (as ""
      # with immutable settings). Ours must win outright; revisit if
      # mutableSettings is ever enabled, since upstream's merger would be
      # discarded here too.
      home.activation.vesktopSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.mkForce ''
          run ${pkgs.writeShellScript "vesktop-settings" ''
            f="$HOME/.config/vesktop/settings/settings.json"
            mkdir -p "$(dirname "$f")"
            [ -s "$f" ] || echo '{}' > "$f"
            jq=${pkgs.jq}/bin/jq
            want='.transparent == false and ((.enabledThemes // []) | index("stylix.css") != null)'
            if ! "$jq" -e "$want" "$f" >/dev/null; then
              "$jq" '.transparent = false
                | .enabledThemes = ((.enabledThemes // []) - ["stylix.css"] + ["stylix.css"])' "$f" > "$f.tmp"
              mv "$f.tmp" "$f"
            fi
          ''}
        ''
      );
    };
}
