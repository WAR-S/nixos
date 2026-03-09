{ ... }:

{
  # Настройка journald: ограничения по месту и сроку хранения логов.
  services.journald = {
    enable = true;
    extraConfig = ''
      SystemMaxUse=500M
      SystemKeepFree=100M
      SystemMaxFileSize=50M
      MaxRetentionSec=4w
    '';
  };
}