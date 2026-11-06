# Overlay for local packages (applied in configuration.nix, so they are
# available as pkgs.<name> everywhere, including home-manager).
final: prev: {
  pipeasio = final.callPackage ./pipeasio { };
  twilight-wallpaper = final.callPackage ./twilight-wallpaper { };
  # Official 32-bit release binary; see pkgs/opence.
  opence = final.pkgsi686Linux.callPackage ./opence { };
  # Full Renoise, built from the licensed tarball in installers/.
  renoise = final.callPackage ./renoise { inherit (prev) renoise; };

  # i686 only: gtest 1.18's test discovery recurses forever when stat() fails
  # with EOVERFLOW (bcachefs inode numbers do not fit in a 32-bit ino_t), so
  # libhwy's build-time test discovery segfaults. Only the 32-bit copy pulled
  # in by Bottles' Wine env is affected, and libjxl already skips its tests on
  # i686, so skip libhwy's too. Drop once gtest handles EOVERFLOW.
  libhwy = prev.libhwy.overrideAttrs (
    _: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isx86_32 { doCheck = false; }
  );
}
