{ config, pkgs, lib, ... }:

let
  iface = "wlp2s0";
  gateway = "10.10.10.1";
  domain = "domain.local";
in
{
  networking.interfaces.${iface}.ipv4.addresses = [
    {
      address = gateway;
      prefixLength = 24;
    }
  ];

  services.hostapd = {
    enable = true;

    radios.${iface} = {
      band = "2g";
      channel = 6;
      countryCode = "US";

      networks.${iface} = {
        ssid = "wifi-nettop-name";

        authentication = {
          mode = "wpa2";
          wpaPassword = "changeme";
        };
      };
    };
  };

  services.dnsmasq = {
    enable = true;

    settings = {
      interface = iface;
      bind-interfaces = true;

      listen-address = gateway;
      port = 53;

      domain = domain;
      address = [ "/.${domain}/${gateway}" ];

      dhcp-range = "10.10.10.2,10.10.10.50,12h";

      no-hosts = true;
      domain-needed = true;
      bogus-priv = true;
    };
  };

  # чтобы NetworkManager не трогал интерфейс
  networking.networkmanager.unmanaged = [ "interface-name:${iface}" ];

  # regulatory domain для iwlwifi
  networking.wireless.regulatoryDomain = "US";
}