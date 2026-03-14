{ config, lib, infra, ... }:

{
  services.resolved.enable = true;

  networking.nameservers = infra.resolver.nameservers;
}
