# Bluetooth, tuned for the DualSense controller.
{ ... }:

{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # pairing GUI + tray applet (XDG autostart)

  # The DualSense connects without a classic bond, and BlueZ rejects HID from
  # non-bonded devices by default ("hidp_add_connection() Rejected connection
  # from !bonded device"), so no gamepad device appears.
  hardware.bluetooth.input.General.ClassicBondedOnly = false;

  # If the adapter isn't pairable, BlueZ pairs the DualSense but never stores
  # a link key, so it can't reconnect after a reboot.
  hardware.bluetooth.settings.General.AlwaysPairable = true;

  # Load the DualSense driver at boot; reconnects fail if it loads late.
  boot.kernelModules = [ "hid_playstation" ];

  # Two Intel radios: the PCIe Wi-Fi card's (8087:0025, used) and an onboard
  # one (8087:0aa7). With both active the DualSense bonds on one and service
  # discovery lands on the other ("Host is down (112)"). Deauthorize the
  # onboard radio. (It hasn't enumerated since early August, so it may also
  # be disabled in firmware now; the rule is harmless either way.)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aa7", ATTR{authorized}="0"
  '';
}
