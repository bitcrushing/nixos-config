# Magicforce numpad (0c45:7018) keeps disconnecting after NumLock presses.
#
# Cause: the pad expects an LED output report after every NumLock press and
# resets its USB connection if none arrives within ~1.4 s. Windows and the
# Linux VT always send one. niri skips it on the ON->OFF transition
# (confirmed with usbmon). The kernel LED path and the firmware are fine:
# on a plain TTY 10/10 presses were answered and the pad never reset.
#
# Fix: a small service that sends the report niri misses. Delete it once
# niri pushes the LED on every NumLock press.
#
# Things that were tried and must not come back:
#   - usbhid.quirks for this device: in current kernels 0x00010000 is
#     HID_QUIRK_SKIP_OUTPUT_REPORTS, which drops every LED report.
#   - Writing a fixed LED value to hidraw (udev rule / keep-alive loop): the
#     LED stops matching niri's NumLock state, so digits stop typing while
#     / * - + still work. It didn't stop the resets either.
#   - Remapping NumLock to "reserved" via hwdb: stops the resets but kills
#     the key and the pad's navigation layer.
{ pkgs, ... }:

{
  systemd.services.numpad-led-responder = {
    description = "Send the Magicforce numpad the NumLock LED report niri misses";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./numpad-led-responder.py}";
      Restart = "always";
      RestartSec = 2;
      # Runs as root: needs the evdev and hidraw nodes (both 0600).
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ ];
      SystemCallFilter = [ "@system-service" ];
    };
  };
}
