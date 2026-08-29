# Low-latency audio via PipeWire.
# Includes a WirePlumber rule forcing the Focusrite Scarlett 6i6 into its
# 5.0 analogue-surround profile, and a udev rule keeping USB autosuspend off
# for the Scarlett so it doesn't drop out.
{ pkgs, ... }:

{
  security.rtkit.enable = true;

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "95";
    }
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-19";
    }
    {
      domain = "@realtime";
      item = "rtprio";
      type = "-";
      value = "95";
    }
    {
      domain = "@realtime";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@realtime";
      item = "nice";
      type = "-";
      value = "-19";
    }
  ];

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

  # Link plugin directories in the system profile
  environment.pathsToLink = [
    "/lib/vst3"
    "/lib/clap"
    "/lib/lv2"
    "/lib/ladspa"
    "/lib/dssi"
  ];

  # Standard plugin search paths for DAWs (Renoise, Bitwig, etc.)
  environment.sessionVariables = {
    VST3_PATH = "$HOME/.vst3:$HOME/.nix-profile/lib/vst3:/etc/profiles/per-user/bitcrushing/lib/vst3:/run/current-system/sw/lib/vst3";
    CLAP_PATH = "$HOME/.clap:$HOME/.nix-profile/lib/clap:/etc/profiles/per-user/bitcrushing/lib/clap:/run/current-system/sw/lib/clap";
    LV2_PATH = "$HOME/.lv2:$HOME/.nix-profile/lib/lv2:/etc/profiles/per-user/bitcrushing/lib/lv2:/run/current-system/sw/lib/lv2";
    LADSPA_PATH = "$HOME/.ladspa:$HOME/.nix-profile/lib/ladspa:/etc/profiles/per-user/bitcrushing/lib/ladspa:/run/current-system/sw/lib/ladspa";
    DSSI_PATH = "$HOME/.dssi:$HOME/.nix-profile/lib/dssi:/etc/profiles/per-user/bitcrushing/lib/dssi:/run/current-system/sw/lib/dssi";
  };
}
