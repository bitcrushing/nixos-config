# Overlay for local packages. Applied in modules/system/nix.nix, so they are
# available as pkgs.<name> everywhere, including home-manager. Nixpkgs
# workarounds live with the module that needs them, not here.
final: prev: {
  pipeasio = final.callPackage ./pipeasio { };
  twilight-wallpaper = final.callPackage ./twilight-wallpaper { };
  wl-uinput-proxy = final.callPackage ./wl-uinput-proxy { };
  # Official 32-bit release binary; see pkgs/opence.
  opence = final.pkgsi686Linux.callPackage ./opence { };
  # Full Renoise, built from the licensed tarball in installers/.
  renoise = final.callPackage ./renoise { inherit (prev) renoise; };
}
