# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko). fileSystems подставляет disko автоматически.
{ infra, ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;   # MBR/BIOS boot partition — для SeaBIOS
    efiSupport = true;              # установка в ESP — для UEFI
    efiInstallAsRemovable = true;   # EFI/BOOT/BOOTX64.EFI — чтобы Proxmox/VM видели диск без NVRAM
  };
  boot.loader.efi.canTouchEfiVariables = false;  # требуется при efiInstallAsRemovable = true

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}