# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Root по LABEL — ядро находит раздел сам (без udev и без ожидания /dev/nvme0n1p3).
{ infra, lib, ... }:

let
  part = n: if lib.hasInfix "nvme" infra.os.diskDevice then "${infra.os.diskDevice}p${toString n}" else "${infra.os.diskDevice}${toString n}";
in
{
  boot.kernelModules = [ "nvme" "nvme_core" ];
  boot.initrd.kernelModules = [ "nvme_core" "nvme" ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "nvme" "nvme_core" ];
  # root=LABEL=nixos — ядро ищет раздел с меткой, не зависит от udev и имени устройства.
  boot.kernelParams = [ "root=LABEL=nixos" "rootfstype=ext4" ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems."/".device = lib.mkForce "LABEL=nixos";
  fileSystems."/".fsType = lib.mkForce "ext4";
  fileSystems."/boot".device = lib.mkForce "LABEL=NIXOS_BOOT";
  fileSystems."/boot".fsType = lib.mkForce "vfat";

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}