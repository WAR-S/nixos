# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Монтирование по LABEL — один toplevel для любого диска (NVMe/SATA); метки заданы в disko-layout.
{ infra, lib, ... }:

{
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems."/".device = lib.mkForce "/dev/disk/by-label/nixos";
  fileSystems."/boot".device = lib.mkForce "/dev/disk/by-label/NIXOS_BOOT";

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}