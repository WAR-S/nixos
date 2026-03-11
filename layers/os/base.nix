{ infra, ... }:

{
  system.stateVersion = "23.11";

  time.timeZone = infra.os.timezone;

  networking.enableIPv6 = false;

  networking.firewall.enable = false;

  # Прошивки для железа (Wi‑Fi iwlwifi, AX200 и т.д.)
  hardware.enableRedistributableFirmware = true;

}