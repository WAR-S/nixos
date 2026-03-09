{ config, pkgs, ... }:

let
  # Скрипт синхронизации времени как отдельный бинарь в /run/current-system/sw/bin/ntp-sync
  ntpSync = pkgs.writeShellScriptBin "ntp-sync" ''
    #!/usr/bin/env bash
    LOGFILE="/var/log/ntp_sync.log"
    ntp_servers=(
        "0.asia.pool.ntp.org"
        "1.asia.pool.ntp.org"
        "2.asia.pool.ntp.org"
        "3.asia.pool.ntp.org"
        "2.vn.pool.ntp.org"
        "vn.pool.ntp.org"
    )

    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting NTP sync..." >> "$LOGFILE"

    for server in "''${ntp_servers[@]}"; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') Trying $server..." >> "$LOGFILE"
        if ntpdate -q "$server" &>/dev/null; then
            if ntpdate -s "$server"; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Synced with $server" >> "$LOGFILE"
                hwclock --systohc || echo "$(date '+%Y-%m-%d %H:%M:%S') Warning: cannot sync hwclock" >> "$LOGFILE"
                exit 0
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') Server $server unreachable" >> "$LOGFILE"
        fi
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') Error: no server worked" >> "$LOGFILE"
    exit 1
  '';
in
{
  systemd.services.ntp-sync = {
    description = "Custom NTP sync with hwclock";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ntpSync}/bin/ntp-sync";
    };
  };

  systemd.timers.ntp-sync = {
    description = "Run custom NTP sync daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "12h";
      Persistent = true;
    };
  };

  # Включаем стандартный systemd-timesyncd для базового NTP
  services.timesyncd.enable = true;
  services.timesyncd.servers = [
    "0.asia.pool.ntp.org"
    "1.asia.pool.ntp.org"
    "2.asia.pool.ntp.org"
    "3.asia.pool.ntp.org"
    "2.vn.pool.ntp.org"
    "vn.pool.ntp.org"
  ];
  # Привязываемся к интерфейсам
  #extraConfig = ''
  #  BindToInterface=eth0,usbmodem0
  #'';
}