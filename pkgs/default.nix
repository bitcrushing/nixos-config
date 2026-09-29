# Overlay for local packages (applied in configuration.nix, so they are
# available as pkgs.<name> everywhere, including home-manager).
final: prev: {
  pipeasio = final.callPackage ./pipeasio { };
  atkinson-nerdfont = final.callPackage ./atkinson-nerdfont { };
  # Full Renoise, built from the licensed tarball in installers/.
  renoise = final.callPackage ./renoise { inherit (prev) renoise; };
}
