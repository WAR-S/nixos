# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Монтирование по имени устройства (nvme0n1p2/p3 или sda2/3).
{ infra, lib, ... }:

let
  # NVMe: nvme0n1p2; SCSI/SATA: sda2, vda2
  part = n:
    if lib.hasInfix "nvme" infra.os.diskDevice
    then "${infra.os.diskDevice}p${toString n}"
    else "${infra.os.diskDevice}${toString n}";
in
{
  # Fallback‑шелл в initrd при проблемах с root.
  boot.kernelParams = [ "boot.shell_on_fail" ];

  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/".device = lib.mkForce (part 3);
  fileSystems."/boot".device = lib.mkForce (part 2);

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}