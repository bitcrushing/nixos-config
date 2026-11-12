# WayVNC serves the running niri session over the tailnet. PAM means the VNC
# password is the normal account password; the TLS key is generated into the
# home directory instead of the world-readable Nix store.
{ pkgs, ... }:

{
  # Adds the CLI and the /etc/pam.d/wayvnc service WayVNC authenticates against.
  programs.wayvnc.enable = true;

  hm =
    { lib, ... }:
    {
      home.activation.wayvncTls = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/wayvnc"
        if [ ! -e "$cfg/tls_key.pem" ]; then
          mkdir -p "$cfg"
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
            -keyout "$cfg/tls_key.pem" -out "$cfg/tls_cert.pem" \
            -subj "/CN=pc" \
            -addext "subjectAltName=DNS:pc,DNS:pc.tailf3f10c.ts.net,DNS:localhost,IP:100.101.244.57,IP:192.168.1.10,IP:127.0.0.1" >/dev/null 2>&1
          chmod 600 "$cfg/tls_key.pem"
        fi
      '';

      home.file.".config/wayvnc/config".text = ''
        address=0.0.0.0
        port=5900
        enable_auth=true
        enable_pam=true
        private_key_file=/home/bitcrushing/.config/wayvnc/tls_key.pem
        certificate_file=/home/bitcrushing/.config/wayvnc/tls_cert.pem
      '';

      # Graphical session service: starts with niri and dies with it, so it never
      # tries to attach to the greeter or run without a compositor.
      #
      # niri 26.04 forwards virtual-keyboard modifiers to the focused window but
      # not to its own bindings, so Super never reaches Mod+... binds. The proxy
      # turns WayVNC's virtual keyboard/pointer into uinput devices, which niri
      # treats like real hardware. Drop the wrapper once niri ships the reworked
      # virtual-keyboard handling (PR #4548, post-26.04).
      systemd.user.services.wayvnc = {
        Unit = {
          Description = "WayVNC remote desktop";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          # Capture the whole logical desktop: the proxy's uinput pointer spans
          # the full layout, so capturing a single output would send clicks to
          # the output at the layout origin instead.
          ExecStart = "${pkgs.wl-uinput-proxy}/bin/wl-uinput-proxy ${pkgs.wayvnc}/bin/wayvnc --desktop";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
