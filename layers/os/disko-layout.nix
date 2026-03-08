# Описание разметки диска. Принимает устройство (для модуля — из infra, для CLI — из DISKO_DEVICE).
# Разделы: BIOS boot (для GRUB/SeaBIOS), ESP (UEFI), root.
{ device }:
{
  disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";  # BIOS boot partition (GRUB legacy)
          content = { type = "none"; };
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [ "-L" "nixos" ];
          };
        };
      };
    };
  };
}
