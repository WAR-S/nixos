# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko). fileSystems подставляет disko автоматически.
# Монтирование по устройству+номеру раздела (без UUID и без by-partlabel — в initrd udev может не успеть).
# Порядок разделов: 1=bios, 2=ESP(/boot), 3=root(/)
{ infra, lib, ... }:

let
  # NVMe: nvme0n1p2; SCSI/SATA: sda2, vda2
  part = n: if lib.hasInfix "nvme" infra.os.diskDevice then "${infra.os.diskDevice}p${toString n}" else "${infra.os.diskDevice}${toString n}";
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;   # MBR/BIOS boot partition — для SeaBIOS
    efiSupport = true;              # установка в ESP — для UEFI
    efiInstallAsRemovable = true;   # EFI/BOOT/BOOTX64.EFI — чтобы Proxmox/VM видели диск без NVRAM
  };
  boot.loader.efi.canTouchEfiVariables = false;  # требуется при efiInstallAsRemovable = true

  # Устройства разделов доступны в initrd без udev
  fileSystems."/".device = lib.mkForce (part 3);
  fileSystems."/boot".device = lib.mkForce (part 2);

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}