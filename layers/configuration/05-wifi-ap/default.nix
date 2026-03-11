{ config, pkgs, lib, ... }:

let
  iface = "wlp2s0";
  ssid = "xxx";
  psk = "qwerty123";
  regdom = "US";

  gateway = "10.10.10.1";
  domain = "domain.local";
  dhcpRange = "10.10.10.2,10.10.10.50,12h";
in
{
  # “Без заморочек”: поднимаем AP через NetworkManager профилем как у тебя.
  networking.networkmanager.enable = true;
  # Регион Wi‑Fi (часто влияет на доступные каналы/AP).
  hardware.firmware = [ pkgs.wireless-regdb ];
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="${regdom}"
  '';

  environment.etc."NetworkManager/system-connections/Wifi.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=Wifi
      type=wifi
      interface-name=${iface}

      [wifi]
      band=bg
      mode=ap
      ssid=${ssid}

      [wifi-security]
      key-mgmt=wpa-psk
      psk=${psk}
      proto=rsn
      group=ccmp
      pairwise=ccmp

      [ipv4]
      address1=${gateway}/24,${gateway}
      dns=${gateway}
      dns-search=${domain}
      method=manual

      [ipv6]
      method=disabled
    '';
  };

  # Перезапуск NM при сборке конфигурации, чтобы профиль подхватился.
  systemd.services.NetworkManager.wantedBy = [ "multi-user.target" ];

  # DNS + DHCP как раньше (можно убрать, если решишь использовать ipv4.method=shared).
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
    };
  };
}