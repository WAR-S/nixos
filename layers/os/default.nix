# OS layer: минимум для сборки edge-node и ISO
# base.nix — stateVersion, timezone, networking
# boot.nix — systemd-boot, EFI, disko (разметка из disko-layout.nix)
# users.nix — пользователи
# packages.nix — systemPackages
# disko.nix — точка входа для CLI (nix run .#disko, автоустановка с ISO)
# disko-layout.nix — схема диска (GPT, ESP, root)
{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./locales.nix
    ./boot.nix
    ./users.nix
    ./packages.nix
    
    ../configuration
  ];
}