{ pkgs, ... }:

{
  systemd.services.update-issue = {
    description = "Generate dynamic issue banner";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "update-issue" ''
        set -euo pipefail

        ${pkgs.neofetch}/bin/neofetch \
          --config /etc/neofetch/config.conf \
          --ascii /etc/neofetch/comp-logo.txt \
          | ${pkgs.gnused}/bin/sed 's/\x1B\[[0-9;]*[mK]//g' \
          > /run/issue

        # Перезапускаем getty, чтобы он перечитал новый /run/issue
        ${pkgs.systemd}/bin/systemctl try-restart getty@tty1.service || true
        ${pkgs.systemd}/bin/systemctl try-restart serial-getty@ttyS0.service || true
      '';
    };
  };

  systemd.timers.update-issue = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
    };
  };

  # agetty по умолчанию печатает /etc/issue, но на NixOS это управляемый файл (symlink в store).
  # Поэтому печатаем динамический баннер из /run/issue.
  systemd.services."getty@tty1".serviceConfig.ExecStart = [
    ""
    "${pkgs.util-linux}/bin/agetty --issue-file /run/issue --noclear %I $TERM"
  ];

  systemd.services."serial-getty@ttyS0".serviceConfig.ExecStart = [
    ""
    "${pkgs.util-linux}/bin/agetty --issue-file /run/issue --keep-baud 115200,38400,9600 %I $TERM"
  ];
}