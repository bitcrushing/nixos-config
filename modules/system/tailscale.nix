# Tailscale mesh VPN and Tailscale SSH: the phone and this host reach each
# other from any network without router port forwards or a public SSH port.
{ ... }:

{
  services.tailscale = {
    enable = true;
    # Interactive login means there is no auth key, so `extraUpFlags` is never
    # applied. `tailscale set` runs on every tailscaled start instead and opts
    # this node into Tailscale SSH (tailscaled answers port 22 on the tailnet;
    # no OpenSSH server is needed), an exit node, and the home LAN as a subnet
    # route. Both routes need approval in the admin console after the first
    # switch, and the /24 must match the LAN on wlp41s0.
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--ssh"
      "--advertise-exit-node"
      "--advertise-routes=192.168.1.0/24"
    ];
    # Opens UDP 41641 so peers connect directly instead of always via DERP.
    openFirewall = true;
  };

  # Tailscale SSH arrives on tailscale0; the LAN and WAN stay closed.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
