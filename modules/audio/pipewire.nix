# Low-latency PipeWire with realtime limits for the audio group, set up for
# the Focusrite Scarlett 6i6.
{ lib, pkgs, ... }:

{
  security.rtkit.enable = true;

  security.pam.loginLimits =
    lib.mapAttrsToList
      (item: value: {
        domain = "@audio";
        type = "-";
        inherit item value;
      })
      {
        rtprio = "95";
        memlock = "unlimited";
        nice = "-19";
      };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    # Fixed 48 kHz / 256 frames. Browsers, games and video are 48k-native;
    # running at 44.1k resampled them live and clipped loud streams.
    extraConfig.pipewire."10-lowlatency"."context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 256;
      "default.clock.max-quantum" = 256;
    };

    # The 6i6 only has surround profiles (which upmix stereo into outputs
    # 3-6) or pro-audio. Pro-audio exposes the six outputs raw, so stereo
    # lands on outputs 1/2.
    wireplumber.extraConfig."51-scarlett-profile"."monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.usb-Focusrite_Scarlett_6i6_USB_00023256-00"; }
        ];
        actions.update-props."device.profile" = "pro-audio";
      }
    ];
  };

  hm.home.packages = with pkgs; [
    pavucontrol # volume mixer (waybar click)
  ];

  # USB autosuspend makes the 6i6 drop out.
  services.udev.extraRules = ''
    ATTR{idVendor}=="1235", ATTR{idProduct}=="8203", ATTR{power/control}="on"
  '';
}
