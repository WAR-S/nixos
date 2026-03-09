{ ... }:

{
  # Настройка journald: ограничения по месту и сроку хранения логов.
  systemd.journald = {
    enable = true;
    extraConfig = ''
      SystemMaxUse=500M
      SystemKeepFree=100M
      SystemMaxFileSize=50M
      MaxRetentionSec=4w
    '';
  };
}