# Krita left-hand keypad: kanata remaps the Magicforce numpad and the Razer
# thumb buttons (layout in ./drawing-keypad/drawing.kbd), only while Krita
# is open. `krita` is wrapped to start kanata-drawing on launch and stop it
# on exit; a polkit rule lets it do that without a password.
{ lib, pkgs, ... }:

{
  services.kanata = {
    enable = true;
    keyboards.drawing = {
      devices = [
        "/dev/input/by-id/usb-magic_force_magic_force_numpad-event-kbd"
        "/dev/input/by-id/usb-magic_force_magic_force_numpad-if01-event-kbd"
        "/dev/input/by-id/usb-Razer_Razer_Basilisk_V3_Pro_35K_000000000000-event-mouse"
        "/dev/input/by-id/usb-Razer_Razer_Basilisk_V3_Pro_35K_000000000000-if01-event-mouse"
      ];
      extraDefCfg = "process-unmapped-keys no";
      config = builtins.readFile ./drawing-keypad/drawing.kbd;
    };
  };
  systemd.services.kanata-drawing = {
    # Started by the krita wrapper, not at boot.
    wantedBy = lib.mkForce [ ];
    # /dev/uinput carries a logind uaccess ACL. If its group was switched to
    # uinput after that ACL was made (first switch with kanata enabled), the
    # ACL keeps `group::---` and kanata (group uinput) gets EACCES. Reset the
    # group entry on every start; "+" runs it as root outside the sandbox.
    serviceConfig.ExecStartPre = "+${pkgs.acl}/bin/setfacl -m g::rw /dev/uinput";
    # OpenRazer's udev rules move the Razer's event nodes to group openrazer
    # (peripherals.nix); kanata only gets `input` from the kanata module.
    serviceConfig.SupplementaryGroups = [ "openrazer" ];
  };

  # While kanata grabs the numpad, numpad-led-responder (numpad.nix) can't
  # see it; this keeps the pad from injecting NumLock and resetting.
  # Starts and stops with kanata-drawing.
  systemd.services.numpad-led-hold = {
    description = "Keep the Magicforce numpad's NumLock LED on while kanata grabs it";
    wantedBy = [ "kanata-drawing.service" ];
    partOf = [ "kanata-drawing.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./drawing-keypad/numpad-led-hold.py}";
      Restart = "always";
      RestartSec = 2;
      # Runs as root: needs the hidraw node (0600).
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ ];
      SystemCallFilter = [ "@system-service" ];
    };
  };

  security.polkit.extraConfig = builtins.readFile ./drawing-keypad/polkit.js;

  # `krita` (PATH and the .desktop entries, which run `krita %F`) goes
  # through the wrapper; everything else is the normal package.
  nixpkgs.overlays = [
    (final: prev: {
      krita = final.symlinkJoin {
        name = "krita-with-keypad-${prev.krita.version}";
        paths = [
          (final.writeShellApplication {
            name = "krita";
            runtimeInputs = [
              final.util-linux
              final.systemd
            ];
            runtimeEnv.KRITA = "${prev.krita}/bin/krita";
            text = builtins.readFile ./drawing-keypad/krita.sh;
          })
          prev.krita
        ];
      };
    })
  ];
}
