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
    # Не полагаемся на systemd *.device units: на некоторых системах они могут не стать "ready",
    # даже если /sys/class/net/<iface> уже существует. Ждём путь напрямую.
    systemd.services.wifi-ap-network = {
      description = "Bring up WiFi AP interface and set IP";
      wantedBy = [ "multi-user.target" ];
      before = [ "hostapd.service" "dnsmasq.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for _ in $(seq 1 50); do
          if [ -e "/sys/class/net/${iface}" ]; then
            break
          fi
          sleep 0.2
        done
        if [ ! -e "/sys/class/net/${iface}" ]; then
          echo "ERROR: interface ${iface} not found in /sys/class/net/"
          exit 1
        fi
        ${pkgs.util-linux}/bin/rfkill unblock all 2>/dev/null || true
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

    # hostapd/dnsmasq запускаем после wifi-ap-network (он поднимает интерфейс и адрес).
    # Важно: модуль NixOS для hostapd добавляет зависимости через unitConfig на sys-subsystem-net-devices-*.device,
    # что у тебя таймаутится. Поэтому unitConfig переопределяем полностью.
    systemd.services.hostapd = {
      unitConfig = lib.mkForce {
        After = "wifi-ap-network.service";
        Wants = "wifi-ap-network.service";
      };
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
