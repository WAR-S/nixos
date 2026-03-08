# Подключает disko к NixOS: разметка из disko-layout.nix, устройство из infrastructure (os.diskDevice).
# fileSystems генерируются автоматически, дублировать в boot.nix не нужно.
{ infra, ... }:
{
  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}
