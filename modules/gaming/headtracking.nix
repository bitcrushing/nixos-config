# Head tracking for Nuclear Option:
#   phone camera --scrcpy--> v4l2loopback (/dev/video10, "PixelCam")
#   --> native opentrack (NeuralNet tracker) --Wine output--> game under Proton
#
# Steam launch option: `nuclearoption-headtrack %command%`
# Scripts are in ./headtracking/.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  script =
    name: runtimeInputs: extra:
    pkgs.writeShellApplication (
      {
        inherit name runtimeInputs;
        text = builtins.readFile ./headtracking/${name}.sh;
      }
      // extra
    );

  opentrack-proton-wine = script "opentrack-proton-wine" [ pkgs.gnused ] {
    runtimeEnv.NIX_LD_LOADER = "${pkgs.glibc}/lib64/ld-linux-x86-64.so.2";
  };
  phone-cam = script "phone-cam" [ pkgs.android-tools pkgs.scrcpy ] { };
  nuclearoption-headtrack =
    script "nuclearoption-headtrack"
      [
        pkgs.android-tools
        pkgs.scrcpy
        pkgs.opentrack
        pkgs.procps
      ]
      {
        bashOptions = [
          "nounset"
          "pipefail"
        ];
      };
  opentrack-wine-setup = script "opentrack-wine-setup" [ pkgs.gnused pkgs.coreutils ] {
    runtimeEnv = {
      OPENTRACK_WINE = "/etc/profiles/per-user/bitcrushing/bin/opentrack-proton-wine";
      OPENTRACK_LIB = "${pkgs.opentrack}/libexec/opentrack";
    };
  };
in
{
  # Virtual camera the phone feed is written to.
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="PixelCam" exclusive_caps=1
  '';

  # opentrack-proton-wine's fallback runs Proton's wine outside the Steam
  # runtime. Its binaries expect the FHS loaders: nix-ld provides the 64-bit
  # one, and the tmpfiles rule the 32-bit one (for lib/wine/i386-unix/wine).
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  };
  systemd.tmpfiles.rules = [
    "L /lib/ld-linux.so.2 - - - - ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2"
  ];

  # Function form to get home-manager's lib (lib.hm.dag).
  hm =
    { lib, ... }:
    {
      home.packages = [
        pkgs.opentrack
        opentrack-proton-wine
        phone-cam
        nuclearoption-headtrack
      ];

      home.activation.opentrackWineSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe opentrack-wine-setup}
      '';
    };
}
