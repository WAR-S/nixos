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
  };

  enabled = wifiAp.enable;
  iface = wifiAp.interface;
  gateway = wifiAp.gateway;
  domain = wifiAp.domain;
  dhcpRange = wifiAp.dhcpRange;
  # Интерфейс в /sys/class/net/ (не в /sys/subsystem/net/devices/ — того может не быть)
  netDevice = "sys-class-net-${iface}.device";
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

    # Поднять интерфейс и назначить IP до hostapd/dnsmasq (wireless часто остаётся DOWN без этого).
    # Ждём интерфейс по /sys/class/net/ (udev уже переименовал wlp0s16 → wlp2s0).
    systemd.services.wifi-ap-network = {
      description = "Bring up WiFi AP interface and set IP";
      wantedBy = [ "multi-user.target" ];
      after = [ netDevice ];
      before = [ "hostapd.service" "dnsmasq.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.iproute2}/bin/ip link set ${iface} up
        ${pkgs.iproute2}/bin/ip addr add ${gateway}/24 dev ${iface} 2>/dev/null || true
      '';
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

    # hostapd по умолчанию ждёт sys-subsystem-net-devices-*.device — на этой системе его нет
    # (/sys/subsystem/net/devices/ отсутствует). Переопределяем на sys-class-net-*.device.
    systemd.services.hostapd = {
      unitConfig.BindsTo = lib.mkForce netDevice;
      unitConfig.After = lib.mkForce "${netDevice} wifi-ap-network.service";
      unitConfig.Requires = lib.mkForce netDevice;
      after = [ "wifi-ap-network.service" ];
      wants = [ "wifi-ap-network.service" ];
    };
    systemd.services.dnsmasq = {
      after = [ "wifi-ap-network.service" "hostapd.service" ];
      wants = [ "wifi-ap-network.service" "hostapd.service" ];
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
