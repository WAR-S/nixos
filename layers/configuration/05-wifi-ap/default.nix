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
      autoconnect=true

      [wifi]
      band=bg
      mode=ap
      ssid=${ssid}
      p2p-disable=1

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

  # Ждём, пока NetworkManager поднимет AP и повесит IP, и только потом стартуем dnsmasq.
  systemd.services.wifi-ap-wait-ip = {
    description = "Wait for WiFi AP IP address";
    after = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    before = [ "dnsmasq.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(seq 1 150); do
        if ${pkgs.iproute2}/bin/ip -4 addr show dev ${iface} | ${pkgs.gnugrep}/bin/grep -q "inet ${gateway}/24"; then
          exit 0
        fi
        sleep 0.2
      done
      echo "ERROR: ${iface} did not get ${gateway}/24 in time"
      ${pkgs.iproute2}/bin/ip -4 addr show dev ${iface} || true
      exit 1
    '';
  };

  systemd.services.dnsmasq = {
    after = [ "wifi-ap-wait-ip.service" ];
    wants = [ "wifi-ap-wait-ip.service" ];
  };

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