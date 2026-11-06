# OpenCE — Halo: Combat Evolved, native 32-bit Linux build (pkgs/opence).
# No game data is included: on first start the game asks for an Xbox disc
# image (.iso/.xiso), or one can be put in ~/.local/share/opence.
{ pkgs, ... }:

{
  # Also set in steam.nix; repeated so OpenCE does not depend on that module.
  hardware.graphics.enable32Bit = true;

  # The release's self-updater installs the upstream binary, which has no
  # NixOS interpreter/rpath and expects /lib/ld-linux.so.2. (The package's
  # own copy is patched by autoPatchelf; an updated one is not.)
  environment.ldso32 = "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2";

  hm.home.packages = [ pkgs.opence ];
}
