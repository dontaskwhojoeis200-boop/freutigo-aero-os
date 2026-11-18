{ lib, ... }:
{
  # Weaker than mkDefault so hosts and test harnesses can override it plainly.
  networking.hostName = lib.mkOverride 1200 "freutigo";

  # NetworkManager: Wi-Fi/Ethernet with a graphical applet in Plasma.
  networking.networkmanager.enable = true;

  # systemd-resolved for DNS (caching, DNS-over-TLS capable, used by NM).
  services.resolved.enable = true;

  # Firewall stays on (section 10.3). Individual features open ports only
  # when explicitly enabled.
  networking.firewall.enable = true;

  # Bluetooth (adapters are optional hardware; the service is cheap when idle).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = lib.mkDefault true;
  };
}
