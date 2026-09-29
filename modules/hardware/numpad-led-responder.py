"""Answer Magicforce numpad (0c45:7018) NumLock presses with an LED report.

Watches interface 0's evdev node. On each NumLock press it flips its idea of
the state and writes the matching LED report to that interface's hidraw node
(byte 0: report ID, 0 = none; byte 1: LED bitmap, bit 0 = NumLock). State is
seeded from the kernel LED and re-synced from EV_LED events, so any update
niri does send wins. See modules/hardware/numpad.nix for why.
"""
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
