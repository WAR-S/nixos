{ infra, lib, ... }:

let
  cfg = infra.network.dns;
in
{

  config = lib.mkIf cfg.enable {

    services.dnsmasq = {
      enable = true;
    };

  };

}