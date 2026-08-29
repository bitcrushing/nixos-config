# Hardware-specific quirks.
#
# NUMPAD (Magicforce, 0c45:7018) — root cause and workaround.
#
# The pad is a low-speed device with two HID interfaces: interface 0 is a
# standard boot keyboard (all keys actually arrive on this one), interface 1 an
# NKRO keyboard (report IDs 4/5/6 carry usages 0x00-0x2f, 0x30-0x67, 0x68-0x9f
# as bitmaps). Neither interface has an interrupt OUT endpoint, so every LED
# report reaches the pad as a control-transfer SET_REPORT on ep0.
#
# ROOT CAUSE: the pad expects the host to answer a NumLock keypress with an LED
# output report, and resets its USB connection if none arrives within ~1.44 s.
# That is legal HID behaviour and Windows always satisfies it, because the
# Windows HID keyboard class driver writes the LED report on every lock-key
# press unconditionally rather than only when the state changes.
#
# niri does not. Captured with usbmon (bus 3):
#
#   789504636  numpad: NumLock press (OFF->ON)
#   789504863  SET_REPORT =01 sent  (+227us)          -> pad happy
#   789656633  numpad: NumLock press (ON->OFF)
#              ... 1.435 s of silence, niri never pushes ...
#   791091726  pad drops off the bus (watchdog fired)
#   791091990  SET_REPORT =00 finally sent, 264 us AFTER the pad died,
#              and only to the other keyboard
#
# So niri misses the LED push on the ON->OFF transition and only flushes it
# when some unrelated device event forces a refresh. Verified not to be a
# kernel bug: driving the LED class directly (echo 1/0 > brightness) produces
# correct SET_REPORTs in both directions, 4/4. Verified not to be a firmware
# defect: on a plain TTY, where the kernel VT driver owns NumLock, 10/10
# presses were answered in ~55 us each and the pad never reset once.
#
# Hence the responder service below. It is a stand-in for the missing niri
# push, not a hardware workaround, and should be deleted once niri is fixed.
#
# TRAP 1: never set usbhid.quirks for this device. An earlier workaround used
# 0x00010000, believing it harmless, but in current kernels BIT(16) is
# HID_QUIRK_SKIP_OUTPUT_REPORTS: usbhid silently drops every LED output
# report, so the compositor could never confirm a numlock toggle to the pad.
#
# TRAP 2: never write a FIXED LED value to hidraw, decoupled from XKB. A udev
# hotplug rule and a polling keep-alive both did this, forcing NumLock-ON
# regardless of actual state. That makes the LED read ON while the compositor
# has NumLock OFF, which presents as "numbers don't type but / * - + do" (those
# four are single-level keys and ignore NumLock) and makes the pad look like it
# has inverted numlock logic. It also never fixed the resets. The responder
# below is NOT this: it writes the current state, in direct response to a
# keypress, exactly as the kernel does on a TTY.
#
# TRAP 3: do not "fix" this by neutering the NumLock key with an hwdb
# KEYBOARD_KEY_70053=reserved remap. That was tried, and it does stop the
# crash, but only by making a key that works fine under Windows stop working
# at all, and it silently costs the pad's whole navigation layer. Rejected.
{ pkgs, ... }:

let
  # Watches interface 0's evdev node. On each NumLock press it flips its idea
  # of the state and writes the matching LED report to that interface's hidraw
  # node (byte 0 is the hidraw report-id prefix, 0 = device uses no report IDs;
  # byte 1 is the LED bitmap, bit 0 = NumLock).
  #
  # State is seeded from the kernel LED at connect and re-synced from any EV_LED
  # event, so whenever niri does manage to push an update that value wins and
  # any drift in the local toggle count is corrected.
  numpadLedResponder = pkgs.writeText "numpad-led-responder.py" ''
    import glob
    import os
    import struct
    import time

    VID = "0c45"
    PID = "7018"

    EV_KEY = 0x01
    EV_LED = 0x11
    KEY_NUMLOCK = 69
    LED_NUML = 0x00

    FMT = "llHHi"
    SIZE = struct.calcsize(FMT)


    def read_attr(path):
        try:
            with open(path) as handle:
                return handle.read().strip()
        except OSError:
            return None


    def find_device():
        for hr_sys in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
            hid_dev = os.path.realpath(os.path.join(hr_sys, "device"))
            usb_if = os.path.dirname(hid_dev)
            usb_dev = os.path.dirname(usb_if)
            if read_attr(os.path.join(usb_dev, "idVendor")) != VID:
                continue
            if read_attr(os.path.join(usb_dev, "idProduct")) != PID:
                continue
            # Interface 0 is the collection that owns the LED output report.
            if read_attr(os.path.join(usb_if, "bInterfaceNumber")) != "00":
                continue
            events = glob.glob(os.path.join(hid_dev, "input", "input*", "event*"))
            if not events:
                continue
            leds = glob.glob(os.path.join(hid_dev, "input", "input*", "*::numlock"))
            led_path = os.path.join(leds[0], "brightness") if leds else None
            ev_path = os.path.join("/dev/input", os.path.basename(events[0]))
            hid_path = os.path.join("/dev", os.path.basename(hr_sys))
            return ev_path, hid_path, led_path
        return None, None, None


    def serve(ev_path, hid_path, led_path):
        state = False
        if led_path:
            state = read_attr(led_path) not in (None, "0")
        with open(ev_path, "rb", buffering=0) as evdev:
            with open(hid_path, "wb", buffering=0) as hidraw:
                while True:
                    data = evdev.read(SIZE)
                    if not data or len(data) < SIZE:
                        return
                    _, _, etype, code, value = struct.unpack(FMT, data)
                    if etype == EV_LED and code == LED_NUML:
                        state = bool(value)
                    elif etype == EV_KEY and code == KEY_NUMLOCK and value == 1:
                        state = not state
                        hidraw.write(bytes([0x00, 0x01 if state else 0x00]))


    def main():
        while True:
            ev_path, hid_path, led_path = find_device()
            if not ev_path:
                time.sleep(2)
                continue
            try:
                serve(ev_path, hid_path, led_path)
            except OSError:
                pass
            time.sleep(1)


    main()
  '';
in
{
  # Logitech device support and Solaar manager
  hardware.logitech.wireless.enable = true;
  programs.solaar = {
    enable = true;
    userService = {
      enable = true;
      window = "hide";
    };
  };

  # Two Bluetooth radios are present: onboard Intel (8087:0aa7) and the PCIe
  # WiFi card's Intel AX BT (8087:0025). Having both active makes the DualSense
  # bond on one adapter while SDP service discovery races/lands on the other,
  # failing with "error updating services: Host is down (112)" so the HID
  # profile never attaches and no gamepad device is created. Deauthorize the
  # onboard radio so only the PCIe card's Bluetooth is used.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aa7", ATTR{authorized}="0"
  '';

  systemd.services.numpad-led-responder = {
    description = "Answer Magicforce numpad NumLock presses with an LED report (works around niri's missed ON->OFF LED push)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 ${numpadLedResponder}";
      Restart = "always";
      RestartSec = 2;
      # Needs read on the evdev node and write on the hidraw node (root 0600).
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
