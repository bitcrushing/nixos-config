"""Keep the Magicforce numpad (0c45:7018) in digit mode while kanata grabs it.

Runs alongside kanata-drawing (see ../drawing-keypad.nix). The evdev grab
blocks niri's LED updates and numpad-led-responder, so without this the pad
thinks NumLock is off, injects NumLock into digit keys, and resets its USB
connection ~1.4 s after each NumLock press (see ../numpad.nix).

hidraw is not affected by the grab: write "NumLock LED on" whenever the pad
(re)appears and answer every NumLock press with the same report. kanata
swallows NumLock taps, so niri's NumLock (on) and the LED stay in step.
"""
import glob
import os
import time

VID, PID = "0c45", "7018"
NUMLOCK_USAGE = 0x53
LED_ON = bytes([0x00, 0x01])  # report ID 0 (none), bit 0 = NumLock


def read_attr(path):
    try:
        with open(path) as handle:
            return handle.read().strip()
    except OSError:
        return None


def find_hidraw():
    for hr_sys in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        hid_dev = os.path.realpath(os.path.join(hr_sys, "device"))
        usb_if = os.path.dirname(hid_dev)
        usb_dev = os.path.dirname(usb_if)
        if (read_attr(os.path.join(usb_dev, "idVendor")) == VID
                and read_attr(os.path.join(usb_dev, "idProduct")) == PID
                and read_attr(os.path.join(usb_if, "bInterfaceNumber")) == "00"):
            return os.path.join("/dev", os.path.basename(hr_sys))
    return None


def serve(path):
    fd = os.open(path, os.O_RDWR)
    try:
        os.write(fd, LED_ON)
        print(f"numpad-led-hold: {path} NumLock LED forced on", flush=True)
        held = False
        while True:
            report = os.read(fd, 64)  # boot keyboard: [mods, 0, k1..k6]
            if not report:
                return
            down = NUMLOCK_USAGE in report[2:8]
            if down and not held:
                os.write(fd, LED_ON)
            held = down
    finally:
        os.close(fd)


def main():
    while True:
        path = find_hidraw()
        if path:
            try:
                serve(path)
            except OSError:
                pass
        time.sleep(0.2)


main()
