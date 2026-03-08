{ ... }:

{
  # fileSystems генерируются из layers/os/disko-layout.nix (disko-module.nix)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}