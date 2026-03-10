# Точка доступа Wi‑Fi на wlp2s0 + dnsmasq (DNS + DHCP).
# Настройки заданы ниже — поменяй ssid, psk, domain при необходимости.
{ config, pkgs, lib, ... }:

let
  # ----- Настройки AP: поменяй под себя -----
  wifiAp = {
    enable = true;
    interface = "wlp2s0";
    ssid = "wifi-nettop-name";
    psk = "changeme";   # WPA2 пароль; для секрета лучше pskFile = "/run/secrets/wifi-psk"
    domain = "domain.local";
    gateway = "10.10.10.1";
    dhcpRange = "10.10.10.2,10.10.10.50,12h";
    upstreamDns = [ "8.8.8.8" "1.1.1.1" ];
  };

  enabled = wifiAp.enable;
  iface = wifiAp.interface;
  gateway = wifiAp.gateway;
  domain = wifiAp.domain;
  dhcpRange = wifiAp.dhcpRange;
  auth = if (wifiAp ? pskFile) && wifiAp.pskFile != null then {
    mode = "wpa2-sha256";
    wpaPasswordFile = wifiAp.pskFile;
  } else if (wifiAp.psk or "") != "" then {
    mode = "wpa2-sha256";
    wpaPassword = wifiAp.psk;
  } else {
    mode = "none";
  };
in
{
  config = lib.mkIf enabled {
    networking.interfaces.${iface} = {
      ipv4.addresses = [{
        address = gateway;
        prefixLength = 24;
      }];
    };

    services.hostapd = {
      enable = true;
      radios.${iface} = {
        band = "2g";
        networks.${iface} = {
          ssid = wifiAp.ssid;
          authentication = auth;
        };
      };
    };

    services.dnsmasq = {
      enable = true;
      settings = {
        no-hosts = true;
        no-resolv = true;
        domain-needed = true;
        bogus-priv = true;
        interface = iface;
        listen-address = gateway;
        port = 53;
        bind-interfaces = true;
        domain = domain;
        address = [ "/.${domain}/${gateway}" ];
        dhcp-range = dhcpRange;
      }
      // lib.optionalAttrs (wifiAp.upstreamDns or [] != []) {
        server = wifiAp.upstreamDns;
      };
    };
  };
}
