{ config, lib, ... }:

{
  #### Глобальный резолвер через systemd-resolved
  #### С акцентом на отказоустойчивость: Cloudflare, Google, Quad9.

  services.resolved = {
    enable = true;

    # Эквивалент /etc/systemd/resolved.conf [Resolve] с явным перечислением DNS/FallbackDNS.
    settings.Resolve = {
      # Основные резолверы (порядок: Cloudflare → Google → Quad9).
      DNS = [
        "1.1.1.1"           # Cloudflare
        "1.0.0.1"           # Cloudflare
        "8.8.8.8"           # Google
        "8.8.4.4"           # Google
        "9.9.9.9"           # Quad9
        "149.112.112.112"   # Quad9
      ];

      # Резервный список. Дублируем те же адреса, чтобы при выпадении части основной группы
      # systemd-resolved мог переключиться на оставшиеся.
      FallbackDNS = [
        "1.1.1.1"
        "1.0.0.1"
        "8.8.8.8"
        "8.8.4.4"
        "9.9.9.9"
        "149.112.112.112"
      ];

      # Можно ужесточить, если захочешь строгую проверку DNSSEC:
      # DNSSEC = "allow-downgrade"; # или "true" / "false"
      #
      # Аналогично с DNS-over-TLS, если понадобится:
      # DNSOverTLS = "opportunistic"; # или "true" / "false"
    };
  };
}

