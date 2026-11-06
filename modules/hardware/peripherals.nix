# Mouse and input tools.
{
  config,
  pkgs,
  ...
}:

{
  # Razer Basilisk V3 Pro 35K (1532:00cd): OpenRazer kernel driver + user daemon.
  hardware.openrazer = {
    enable = true;
    users = [ "bitcrushing" ];
  };

  # Kernel 7.2.11's aggregateModules expects signed external modules
  # (nixpkgs#575192). Install through modules_install as in upstream commit
  # 965f876a78; drop this once that fix reaches our nixpkgs.
  hardware.openrazer.packages.kernel = config.boot.kernelPackages.openrazer.overrideAttrs (old: {
    makeFlags = (old.makeFlags or [ ]) ++ [
      "INSTALL_MOD_PATH=${placeholder "out"}"
      "INSTALL_MOD_DIR=kernel/drivers/hid"
      "INSTALL_MOD_STRIP=1"
      "DEPMOD=true"
    ];
    installTargets = [ "modules_install" ];
    installFlags = [
      "-C"
      "${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
      "M=$(PWD)/driver"
    ];
    installPhase = null;
    postInstall = ''
      RAZER_MOUNT_OUT="$out/bin/razer_mount"
      RAZER_RULES_OUT="$out/etc/udev/rules.d/99-razer.rules"
      install -m 644 -v -D install_files/udev/99-razer.rules $RAZER_RULES_OUT
      install -m 755 -v -D install_files/udev/razer_mount $RAZER_MOUNT_OUT
      substituteInPlace $RAZER_RULES_OUT \
        --replace razer_mount $RAZER_MOUNT_OUT \
        --replace plugdev openrazer
      substituteInPlace $RAZER_MOUNT_OUT \
        --replace /usr/bin/logger ${pkgs.util-linux}/bin/logger \
        --replace chgrp ${pkgs.coreutils}/bin/chgrp \
        --replace "PATH='/sbin:/bin:/usr/sbin:/usr/bin'" "" \
        --replace plugdev openrazer
    '';
  });

  # Remaps extra mouse buttons at the evdev level (works under Wayland).
  services.input-remapper.enable = true;

  # input-remapper-gtk runs its key recorder through pkexec, and polkit no
  # longer installs pkexec setuid by default.
  security.polkit.enablePkexecWrapper = true;

  environment.systemPackages = with pkgs; [
    polychromatic # OpenRazer GUI
    usbutils # lsusb
  ];
}
