# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Монтирование по пути устройства (nvme0n1p2/p3 или sda2/3) — в initrd не нужен udev для by-label.
{ infra, lib, ... }:

let
  part = n: if lib.hasInfix "nvme" infra.os.diskDevice then "${infra.os.diskDevice}p${toString n}" else "${infra.os.diskDevice}${toString n}";
in
{
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "nvme" ];
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems."/".device = lib.mkForce (part 3);
  fileSystems."/boot".device = lib.mkForce (part 2);

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}