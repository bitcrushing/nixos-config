# Printing via CUPS, with HP drivers.
{ pkgs, ... }:

{
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
}
