# qBittorrent's GUI is only a frontend; qbittorrent-nox serves the Web UI and
# keeps downloading without a desktop session. It shares the GUI's profile
# (~/.config/qBittorrent), so the two cannot run at the same time.
{ pkgs, ... }:

{
  # The user service has to outlive the login session, otherwise it stops when
  # the desktop logs out and the phone can no longer reach the Web UI.
  users.users.bitcrushing.linger = true;

  hm = {
    home.packages = [ pkgs.qbittorrent ];

    systemd.user.services.qbittorrent = {
      Unit.Description = "qBittorrent headless (Web UI)";
      Service = {
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
        # A clean stop is how the desktop GUI is given the profile back, so
        # only restart after crashes.
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
