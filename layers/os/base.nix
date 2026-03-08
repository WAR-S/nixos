{ infra, ... }:

{
  system.stateVersion = "23.11";

  time.timeZone = infra.os.timezone;

  networking.enableIPv6 = false;
  networking = {
  interfaces.ens18.ipv4.addresses = [{
    address = "192.168.10.228";
    prefixLength = 24;
  }];
  defaultGateway = "192.168.10.1";
  nameservers = [ "8.8.8.8" ];
  useDHCP = false; # Disable global DHCP
};  
  networking.firewall.enable = false;
}