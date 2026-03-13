{ config, lib, ... }:

{
  #### Глобальный резолвер через systemd-resolved
  #### С акцентом на отказоустойчивость: Cloudflare, Google, Quad9.

  # В твоём канале нет ни services.resolved.settings, ни services.resolved.dns,
  # поэтому используем самый совместимый путь:
  #
  # - включаем systemd-resolved
  # - задаём глобальные DNS через networking.nameservers

  services.resolved.enable = true;

  networking.nameservers = [
    "1.1.1.1"           # Cloudflare
    "1.0.0.1"           # Cloudflare
    "8.8.8.8"           # Google
    "8.8.4.4"           # Google
    "9.9.9.9"           # Quad9
    "149.112.112.112"   # Quad9
  ];
}


