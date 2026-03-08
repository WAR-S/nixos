# Загрузчик + разметка диска (disko). fileSystems подставляет disko автоматически.
{ infra, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}