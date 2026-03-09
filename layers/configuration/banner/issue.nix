{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.neofetch ];

  systemd.services.update-issue = {
    description = "Generate dynamic /etc/issue";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-issue" ''
        ${pkgs.neofetch}/bin/neofetch \
          --config /etc/neofetch/config.conf \
          --stdout \
          | ${pkgs.gnused}/bin/sed 's/\x1B\[[0-9;]*[mK]//g' \
          > /etc/issue
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
}