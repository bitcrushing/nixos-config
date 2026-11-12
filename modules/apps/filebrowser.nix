# Browser-based file manager for the home directory, reachable over Tailscale.
# 8081 because 8080 is qBittorrent's Web UI.
{ ... }:

{
  services.filebrowser = {
    enable = true;
    user = "bitcrushing";
    group = "users";
    settings = {
      address = "0.0.0.0";
      port = 8081;
      root = "/home/bitcrushing";
    };
  };

  # Quick-setup credentials stay out of this public repo: the bcrypt hash is
  # read from a 0600 local file and is only used when the database is created.
  systemd.services.filebrowser.serviceConfig.EnvironmentFile = "-/var/lib/filebrowser/env";
}
