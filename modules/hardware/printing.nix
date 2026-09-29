# CUPS with HP drivers; avahi finds network printers.
{ pkgs, ... }:

{
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  services.avahi.enable = true;
}
