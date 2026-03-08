{ infra, lib, ... }:

let
  cfg = infra.network.wifi_ap;
in
{

  config = lib.mkIf cfg.enabled {

    services.hostapd = {
      enable = true;
      ssid = cfg.ssid;
      wpaPassphrase = cfg.password;
    };

  };

}