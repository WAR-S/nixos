# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Root по by-label; ждём udev в preMountCommands, чтобы симлинк существовал до монтирования.
{ infra, lib, ... }:

let
  part = n: if lib.hasInfix "nvme" infra.os.diskDevice then "${infra.os.diskDevice}p${toString n}" else "${infra.os.diskDevice}${toString n}";
in
{
  boot.kernelModules = [ "nvme" "nvme_core" ];
  boot.initrd.kernelModules = [ "nvme_core" "nvme" ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "nvme" "nvme_core" ];
  # Если stage 1 падает (root не монтируется и т.п.) — провалиться в shell вместо мгновенной ошибки.
  boot.kernelParams = [ "boot.shell_on_fail" ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;
    efiSupport = true;
    efiInstallAsRemovable = true;  # fallback EFI/BOOT/BOOTX64.EFI для VM/Proxmox
  };
  # true — писать загрузочную запись в NVRAM, чтобы не выбирать диск в BIOS каждый раз.
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/".device = lib.mkForce "/dev/disk/by-label/nixos";
  fileSystems."/".fsType = lib.mkForce "ext4";
  fileSystems."/".options = [ "x-systemd.device-timeout=120" ];
  fileSystems."/boot".device = lib.mkForce "/dev/disk/by-label/NIXOS_BOOT";
  fileSystems."/boot".fsType = lib.mkForce "vfat";
  fileSystems."/boot".options = [ "x-systemd.device-timeout=120" ];

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}