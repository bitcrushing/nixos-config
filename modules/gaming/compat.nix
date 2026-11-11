# Shared compatibility layer for games and Wine tools: 32-bit graphics and
# loader support, nix-ld, and the i686 libhwy fix pulled in by Bottles.
{ pkgs, ... }:

{
  # 32-bit Mesa for 32-bit Proton and OpenCE titles.
  hardware.graphics.enable32Bit = true;

  # Release binaries and self-updaters that expect the FHS loader (OpenCE's
  # updater, opentrack-proton-wine's fallback).
  environment.ldso32 = "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2";

  # opentrack-proton-wine's fallback runs Proton's wine outside the Steam
  # runtime. Its binaries expect the FHS loaders: nix-ld provides the 64-bit
  # one, and ldso32 above provides the 32-bit one (lib/wine/i386-unix/wine).
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

  # i686 only: gtest 1.18's test discovery recurses forever when stat() fails
  # with EOVERFLOW (bcachefs inode numbers do not fit in a 32-bit ino_t), so
  # libhwy's build-time test discovery segfaults. Only the 32-bit copy pulled
  # in by Bottles' Wine env is affected, and libjxl already skips its tests on
  # i686, so skip libhwy's too. Drop once gtest handles EOVERFLOW.
  nixpkgs.overlays = [
    (_final: prev: {
      libhwy = prev.libhwy.overrideAttrs (
        _: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isx86_32 { doCheck = false; }
      );
    })
  ];
}
