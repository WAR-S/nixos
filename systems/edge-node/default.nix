{ infra, ... }:

{
  networking.hostName = infra.os.hostname;
}