# Hardware-specific quirks: Magicforce numpad firmware workaround.
# The numpad (0c45:7018) crashes its firmware unless NumLock is held ON and
# usbhid is told to ignore its report descriptor quirks.
{ pkgs, ... }:

{
  boot.kernelParams = [ "usbhid.quirks=0x0c45:0x7018:0x00010000" ];

  boot.extraModprobeConfig = ''
    options usbhid quirks=0x0c45:0x7018:0x00010000
  '';

  systemd.services.numpad-numlock-fix = {
    description = "Hold NumLock ON for the Magicforce numpad (0c45:7018) to stop its firmware-reset loop";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 2;
      ExecStart = pkgs.writeShellScript "numpad-numlock-fix" ''
         # Tell the numpad (interface 0 = the boot-keyboard collection that owns the LED
        # output report) that NumLock is ON. hidraw output report layout for this device:
         #   byte0 = report id (0 = none),  byte1 = LED bitmap (bit0 = NumLock).
         while :; do
           active=0
           for d in /sys/class/hidraw/hidraw*; do
             [ -e "$d/device/uevent" ] || continue
             ue=$(< "$d/device/uevent")
             case "$ue" in *0003:00000C45:00007018*) ;; *) continue ;; esac
             ifn=$(< "$d/device/../bInterfaceNumber")
             [ "$ifn" = "00" ] || continue
             printf '\000\001' > "/dev/''${d##*/}" 2>/dev/null || true
             active=1
           done
           if [ "$active" = 1 ]; then sleep 0.25; else sleep 2; fi
         done
      '';
    };
  };

  # Force number input regardless of numlock state
  services.udev.extraHwdb = ''
    evdev:input:b0003v0C45p7018*
     KEYBOARD_KEY_70059=1
     KEYBOARD_KEY_7005a=2
     KEYBOARD_KEY_7005b=3
     KEYBOARD_KEY_7005c=4
     KEYBOARD_KEY_7005d=5
     KEYBOARD_KEY_7005e=6
     KEYBOARD_KEY_7005f=7
     KEYBOARD_KEY_70060=8
     KEYBOARD_KEY_70061=9
     KEYBOARD_KEY_70062=0
     KEYBOARD_KEY_70063=dot
     KEYBOARD_KEY_70053=reserved
  '';
}

  # Two Bluetooth radios are present: onboard Intel (8087:0aa7) and the PCIe
  # WiFi card's Intel AX BT (8087:0025). Having both active makes the DualSense
  # bond on one adapter while SDP service discovery races/lands on the other,
  # failing with "error updating services: Host is down (112)" so the HID
  # profile never attaches and no gamepad device is created. Deauthorize the
  # onboard radio so only the PCIe card's Bluetooth is used.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aa7", ATTR{authorized}="0"
  '';

