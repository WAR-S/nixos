# Загрузчик (GRUB: UEFI + SeaBIOS) + разметка диска (disko).
# Монтирование по пути устройства (nvme0n1p2/p3 или sda2/3) — в initrd не нужен udev для by-label.
{ infra, lib, ... }:

let
  part = n: if lib.hasInfix "nvme" infra.os.diskDevice then "${infra.os.diskDevice}p${toString n}" else "${infra.os.diskDevice}${toString n}";
  rootPart = part 3;
in
{
  boot.kernelModules = [ "nvme" "nvme_core" ];
  # Грузить NVMe сразу при старте initrd (до preDeviceCommands и до монтирования root).
  boot.initrd.kernelModules = [ "nvme_core" "nvme" ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "nvme" "nvme_core" ];
  # Ждём появления раздела (nvme уже загружен через kernelModules).
  boot.initrd.preDeviceCommands = ''
    echo "Waiting for ${rootPart}..."
    i=0
    while [ "$i" -lt 120 ]; do
      [ -b "${rootPart}" ] && { echo "Found ${rootPart}"; break; }
      sleep 1
      i=$((i + 1))
    done
    [ -b "${rootPart}" ] || { echo "ERROR: ${rootPart} not found after 120s"; exit 1; }
  '';
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = infra.os.diskDevice;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # NVMe-разделы могут появляться с задержкой — ждём до 2 минут.
  fileSystems."/".device = lib.mkForce (part 3);
  fileSystems."/".options = [ "x-systemd.device-timeout=120" ];
  fileSystems."/boot".device = lib.mkForce (part 2);
  fileSystems."/boot".options = [ "x-systemd.device-timeout=120" ];

  disko.devices = import ./disko-layout.nix { device = infra.os.diskDevice; };
}