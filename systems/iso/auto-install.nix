# Модуль для самоустанавливающегося ISO.
# Загрузка с параметрами ядра: nixos.autoInstall=1 nixos.installDisk=/dev/sda
# Тогда при старте выполнится разметка (disko), копирование конфига и nixos-install.
{ config, pkgs, flakeSrc, diskoPackage, ... }:

let
  # PATH для скрипта: disko, nix, coreutils и т.д.
  installPath = pkgs.lib.makeBinPath [
    pkgs.gnugrep
    pkgs.util-linux
    pkgs.nix
    pkgs.coreutils
    diskoPackage
  ];
in
{
  # Уменьшение размера ISO: более сильное сжатие squashfs
  isoImage.squashfsCompression = "xz -Xdict-size 100%";
  # Опционально: только xz (без dict-size даёт чуть больший размер, но быстрее собирается)
  # isoImage.squashfsCompression = "xz";

  # Кладём флейк в образ, чтобы установщик мог его использовать
  isoImage.contents = [
    { source = flakeSrc; target = "/iso/nixos-config"; }
  ];

  # disko нужен для автоматической разметки при самоустановке
  environment.systemPackages = [ diskoPackage ];

  # Сервис: при загрузке с nixos.autoInstall=1 запускает установку (script — строка, не derivation)
  systemd.services.nixos-auto-install = {
    description = "NixOS auto-install to disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -e
      export PATH="${installPath}:$PATH"

      get_cmdline() {
        for param in $(cat /proc/cmdline); do
          case "$param" in
            nixos.autoInstall=*)
              echo "''${param#nixos.autoInstall=}"
              return
              ;;
          esac
        done
      }
      get_disk() {
        for param in $(cat /proc/cmdline); do
          case "$param" in
            nixos.installDisk=*)
              echo "''${param#nixos.installDisk=}"
              return
              ;;
          esac
        done
        echo "/dev/sda"
      }

      AUTO="$(get_cmdline)"
      DISK="$(get_disk)"

      [[ "$AUTO" != "1" && "$AUTO" != "true" ]] && exit 0

      echo "=== NixOS auto-install: disk=$DISK ==="
      export DISKO_DEVICE="$DISK"

      echo ">>> Running disko (destroy+format+mount)..."
      disko --mode destroy,format,mount /iso/nixos-config/layers/os/disko.nix

      echo ">>> Copying flake to /mnt/etc/nixos..."
      mkdir -p /mnt/etc
      cp -r /iso/nixos-config /mnt/etc/nixos

      echo ">>> Running nixos-install..."
      nixos-install --flake /mnt/etc/nixos#edge-node --no-root-passwd

      echo ">>> Done. Rebooting in 5s..."
      sleep 5
      reboot
    '';
  };
}
