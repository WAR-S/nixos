{ config, lib, pkgs, infra, ... }:

let
  cfg =
    if (infra ? vpn) && (infra.vpn ? openvpn) then infra.vpn.openvpn else null;

  enabled = cfg != null && (cfg.enable or true);

  # Базовый маршрут из примера
  routeNet = (cfg.routeNet or "127.0.0.1");
  routeMask = (cfg.routeMask or "255.255.0.0");

  # Если перед сборкой дернули scripts/fetch-openvpn-from-vault.sh — тут появятся файлы.
  fetchedDir = ../../secrets/openvpn;
  fetchedCa = fetchedDir + "/ca.crt";
  fetchedCert = fetchedDir + "/client.crt";
  fetchedKey = fetchedDir + "/client.key";
  fetchedTlsAuth = fetchedDir + "/tls-auth.key";

  # OpenVPN-конфиг.
  clientConf = ''
    client
    dev tun0
    proto tcp
    remote ${cfg.remoteHost or "127.0.0.1"} ${toString (cfg.remotePort or 1194)}
    resolv-retry infinite
    float
    ping-restart 60
    route ${routeNet} ${routeMask}
    persist-key
    persist-tun
    remote-cert-tls server
    auth SHA512
    ignore-unknown-option block-outside-dns
    verb 3
    script-security 2
    up /etc/openvpn/update-systemd-resolve.sh
    up-restart
    down /etc/openvpn/update-systemd-resolve.sh
    down-pre
  '';

  # Скрипт для systemd-resolved (через resolvectl). Достаточно для большинства кейсов:
  # OpenVPN передаёт DNS как foreign_option_*, например: "dhcp-option DNS 10.0.0.2".
  updateResolved = pkgs.writeShellScript "update-systemd-resolve.sh" ''
    #!/usr/bin/env sh
    set -eu

    IFACE="''${dev:-tun0}"
    ACTION="''${script_type:-}"

    collect_dns() {
      i=1
      while :; do
        opt="$(eval "printf '%s' \"\${foreign_option_''${i}:-}\"")"
        [ -z "$opt" ] && break
        case "$opt" in
          *"dhcp-option DNS "*)
            echo "$opt" | sed -n 's/.*dhcp-option DNS \([0-9a-fA-F\.:]\+\).*/\1/p'
            ;;
        esac
        i=$((i+1))
      done
    }

    if command -v resolvectl >/dev/null 2>&1; then
      case "$ACTION" in
        up)
          DNS="$(collect_dns | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
          if [ -n "$DNS" ]; then
            resolvectl dns "$IFACE" $DNS || true
            resolvectl domain "$IFACE" "~." || true
          fi
          ;;
        down)
          resolvectl revert "$IFACE" || true
          ;;
      esac
    fi

    exit 0
  '';

  # Секреты можно указать как файлы (пути) или inline-строки. Inline попадёт в /nix/store.
  caFile =
    if (cfg.caFile or null) != null then cfg.caFile
    else if builtins.pathExists fetchedCa then toString fetchedCa
    else null;
  certFile =
    if (cfg.certFile or null) != null then cfg.certFile
    else if builtins.pathExists fetchedCert then toString fetchedCert
    else null;
  keyFile =
    if (cfg.keyFile or null) != null then cfg.keyFile
    else if builtins.pathExists fetchedKey then toString fetchedKey
    else null;
  tlsCryptFile =
    if (cfg.tlsCryptFile or null) != null then cfg.tlsCryptFile
    else null;
  # В твоём Vault поле называется tls-auth (не tls-crypt)
  tlsAuthFile =
    if (cfg.tlsAuthFile or null) != null then cfg.tlsAuthFile
    else if builtins.pathExists fetchedTlsAuth then toString fetchedTlsAuth
    else null;

  caInline = cfg.caInline or null;
  certInline = cfg.certInline or null;
  keyInline = cfg.keyInline or null;
  tlsCryptInline = cfg.tlsCryptInline or null;

  caStoreFile = if caInline != null then pkgs.writeText "openvpn-ca.crt" caInline else null;
  certStoreFile = if certInline != null then pkgs.writeText "openvpn-client.crt" certInline else null;
  keyStoreFile = if keyInline != null then pkgs.writeText "openvpn-client.key" keyInline else null;
  tlsCryptStoreFile = if tlsCryptInline != null then pkgs.writeText "openvpn-tls-crypt.key" tlsCryptInline else null;

  effectiveCaFile = if caFile != null then caFile else (if caStoreFile != null then "/etc/openvpn/ca.crt" else null);
  effectiveCertFile = if certFile != null then certFile else (if certStoreFile != null then "/etc/openvpn/client.crt" else null);
  effectiveKeyFile = if keyFile != null then keyFile else (if keyStoreFile != null then "/etc/openvpn/client.key" else null);
  effectiveTlsCryptFile = if tlsCryptFile != null then tlsCryptFile else (if tlsCryptStoreFile != null then "/etc/openvpn/tls-crypt.key" else null);

  secretDirectives = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
    (if effectiveCaFile != null then "ca ${effectiveCaFile}" else "")
    (if effectiveCertFile != null then "cert ${effectiveCertFile}" else "")
    (if effectiveKeyFile != null then "key ${effectiveKeyFile}" else "")
    (if effectiveTlsCryptFile != null then "tls-crypt ${effectiveTlsCryptFile}" else "")
    (if tlsAuthFile != null then "tls-auth ${tlsAuthFile}" else "")
  ]);

  finalConf = clientConf + (if secretDirectives != "" then "\n" + secretDirectives + "\n" else "");
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = [ pkgs.openvpn ];

    # Скрипт, который referenced в client.conf
    environment.etc."openvpn/update-systemd-resolve.sh" = {
      source = updateResolved;
      mode = "0755";
    };

    # Если секреты заданы inline — кладём их в /etc/openvpn как обычные файлы.
    environment.etc = lib.mkMerge [
      (lib.mkIf (caStoreFile != null) { "openvpn/ca.crt".source = caStoreFile; })
      (lib.mkIf (certStoreFile != null) { "openvpn/client.crt".source = certStoreFile; })
      (lib.mkIf (keyStoreFile != null) { "openvpn/client.key".source = keyStoreFile; mode = "0400"; })
      (lib.mkIf (tlsCryptStoreFile != null) { "openvpn/tls-crypt.key".source = tlsCryptStoreFile; mode = "0400"; })
    ];

    # OpenVPN client service.
    services.openvpn.servers."client" = {
      autoStart = true;
      config = finalConf;
    };

    # На всякий случай — интерфейс туннеля требует net_admin.
    systemd.services."openvpn-client".serviceConfig = {
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
    };
  };
}

