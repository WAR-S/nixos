# Модуль для самоустанавливающегося ISO.
# По умолчанию при загрузке автоматически запускается установка на указанный диск.
# Чтобы загрузиться без установки — в GRUB (e) убери из строки linux: nixos.autoInstall=1 и nixos.installDisk=...
# На live-системе вызываем disko через nix run из флейка на ISO — так nix подтянет closure из кэша (nixpkgs не в store образа).
{ config, pkgs, flakeSrc, ... }:

let
  # Диск по умолчанию для автоустановки (Proxmox: SCSI/IDE → /dev/sda, VirtIO → /dev/vda)
  defaultInstallDisk = "/dev/sda";

  installPath = pkgs.lib.makeBinPath [
    pkgs.gnugrep
    pkgs.util-linux
    pkgs.nix
    pkgs.coreutils
  ];
in
{
  # Параметры ядра по умолчанию: автоустановка при загрузке без правки GRUB
  boot.kernelParams = [
    "nixos.autoInstall=1"
    "nixos.installDisk=${defaultInstallDisk}"
  ];

  # Уменьшение размера ISO: более сильное сжатие squashfs
  isoImage.squashfsCompression = "xz -Xdict-size 100%";
  # Опционально: только xz (без dict-size даёт чуть больший размер, но быстрее собирается)
  # isoImage.squashfsCompression = "xz";

  # Кладём флейк в корень ISO (на live-системе может быть /iso/nixos-config или /run/iso/nixos-config)
  isoImage.contents = [
    { source = flakeSrc; target = "/nixos-config"; }
  ];

  # nix с flakes — disko вызываем через nix run из флейка на ISO
  environment.systemPackages = [ pkgs.nix ];

  # Сервис: при загрузке с nixos.autoInstall=1 запускает установку (script — строка, не derivation)
  systemd.services.nixos-auto-install = {
    description = "NixOS auto-install to disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
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
        echo "${defaultInstallDisk}"
      }

      AUTO="$(get_cmdline)"
      DISK="$(get_disk)"

      [[ "$AUTO" != "1" && "$AUTO" != "true" ]] && exit 0

      echo "=== NixOS auto-install: disk=$DISK ==="
      export DISKO_DEVICE="$DISK"

      # Ищем каталог флейка. На NixOS live ISO контент часто в /iso/iso/nixos-config (sr0 смонтирован в /iso).
      CONFIG_DIR=""
      for p in "/iso/iso/nixos-config" "/iso/nixos-config" "/run/iso/nixos-config" "/mnt/cdrom/nixos-config"; do
        [[ -f "$p/flake.nix" && -f "$p/layers/os/disko.nix" ]] && CONFIG_DIR="$p" && break
      done
      if [[ -z "$CONFIG_DIR" ]]; then
        CONFIG_DIR="$(find /iso /run /mnt /cdrom -name "disko.nix" -path "*/layers/os/disko.nix" 2>/dev/null | head -1 | xargs dirname | xargs dirname | xargs dirname)"
      fi
      if [[ -z "$CONFIG_DIR" || ! -f "$CONFIG_DIR/flake.nix" ]]; then
        echo "ERROR: nixos-config (flake) не найден на образе. Проверьте: ls -laR /iso /run/iso"
        exit 1
      fi
      echo ">>> Flake: $CONFIG_DIR"

      DISKO_CONFIG="$CONFIG_DIR/layers/os/disko.nix"
      [[ ! -f "$DISKO_CONFIG" ]] && echo "ERROR: нет файла $DISKO_CONFIG" && exit 1

      # Подтягиваем closure флейка (в т.ч. nixpkgs) и получаем путь для NIX_PATH
      echo ">>> Resolving nixpkgs path from flake..."
      NIXPKGS_PATH_FILE="$(cd "$CONFIG_DIR" && nix --extra-experimental-features "nix-command flakes" build .#nixpkgs-path-file --print-out-paths --no-link 2>/dev/null | head -1)"
      if [[ -n "$NIXPKGS_PATH_FILE" && -f "$NIXPKGS_PATH_FILE" ]]; then
        export NIX_PATH="nixpkgs=$(cat "$NIXPKGS_PATH_FILE"):''${NIX_PATH:-}"
      fi

      echo ">>> Running disko (destroy+format+mount)..."
      cd "$CONFIG_DIR" && nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode destroy,format,mount "$DISKO_CONFIG"

      echo ">>> Copying flake to /mnt/etc/nixos..."
      mkdir -p /mnt/etc
      cp -r "$CONFIG_DIR" /mnt/etc/nixos

      echo ">>> Running nixos-install..."
      nixos-install --flake /mnt/etc/nixos#edge-node --no-root-passwd

      echo ">>> Done. Rebooting in 5s..."
      sleep 5
      reboot
    '';
  };
}
