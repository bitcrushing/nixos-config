# Low-latency audio via PipeWire.
# Includes a WirePlumber rule forcing the Focusrite Scarlett 6i6 into its
# 5.0 analogue-surround profile, and a udev rule keeping USB autosuspend off
# for the Scarlett so it doesn't drop out.
{ pkgs, ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire."10-lowlatency" = {
      "context.properties" = {
        "default.clock.rate" = 44100;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
      };
    };
  };

  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/main.lua.d/99-scarlett-profile.lua" ''
      rule = {
        matches = {
          {
            { "device.name", "matches", "alsa_card.usb-Focusrite_Scarlett_6i6_USB_00023256-00" },
          },
        },
        apply_properties = {
          ["device.profile"] = "output:analog-surround-50",
        },
      }
    '')
  ];

  # Disable USB autosuspend for the Focusrite Scarlett 6i6 to prevent dropouts
  services.udev.extraRules = ''
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8202", ATTR{power/control}="on"
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8203", ATTR{power/control}="on"
  '';
}
