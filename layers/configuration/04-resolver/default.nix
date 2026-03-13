{ config, lib, ... }:

{
  #### Глобальный резолвер через systemd-resolved
  #### С акцентом на отказоустойчивость: Cloudflare, Google, Quad9.

  services.resolved = {
    enable = true;

    # Старый интерфейс NixOS (dns / fallbackDns), совместимый с твоим каналом.
    dns = [
      "1.1.1.1"           # Cloudflare
      "1.0.0.1"           # Cloudflare
      "8.8.8.8"           # Google
      "8.8.4.4"           # Google
      "9.9.9.9"           # Quad9
      "149.112.112.112"   # Quad9
    ];

    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
      "9.9.9.9"
      "149.112.112.112"
    ];

    # При желании можно включить:
    # dnssec = "allow-downgrade";   # или "true" / "false"
    # dnsovertls = "opportunistic"; # или "true" / "false"
  };
}

