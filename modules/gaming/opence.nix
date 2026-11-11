# OpenCE — Halo: Combat Evolved, native 32-bit Linux build (pkgs/opence).
# No game data is included: on first start the game asks for an Xbox disc
# image (.iso/.xiso), or one can be put in ~/.local/share/opence.
# 32-bit graphics and the FHS loader come from compat.nix.
{ pkgs, ... }:

{
  hm.home.packages = [ pkgs.opence ];
}
