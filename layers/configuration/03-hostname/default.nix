{ pkgs, ... }:

{
  # Задаём hostname на основе серийного номера железки (dmidecode -s system-serial-number)
  systemd.services.set-hostname-from-serial = {
    description = "Set hostname from DMI system serial number";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "set-hostname-from-serial" ''
        set -euo pipefail

        # Читаем серийник, чистим пробелы/лишние символы
        SN="$(${pkgs.dmidecode}/sbin/dmidecode -s system-serial-number 2>/dev/null | head -n1 | tr ' ' '-' | tr -cd 'A-Za-z0-9-')"

        if [ -n "$SN" ]; then
          # На NixOS hostnamectl менять hostname не даёт, используем классический hostname(1)
          ${pkgs.hostname}/bin/hostname "$SN" || true
        fi
      '';
    };
  };
}

