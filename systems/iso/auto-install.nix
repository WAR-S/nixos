# Модуль для самоустанавливающегося ISO.
# По умолчанию при загрузке автоматически запускается установка на указанный диск.
# Чтобы загрузиться без установки — в GRUB (e) убери из строки linux: nixos.autoInstall=1 и nixos.installDisk=...
# ISO рассчитан на офлайн: disko и замыкание edge-node кладём в образ при сборке.
{ config, pkgs, lib, flakeSrc, diskoPackage, edgeNodeToplevel, infra, ... }:

let
  releaseName = infra."release-name" or "nixos-nettop";

  installPath = pkgs.lib.makeBinPath [
    pkgs.gnugrep
    pkgs.util-linux
    pkgs.nix
    pkgs.coreutils
    pkgs.nixos-install-tools
    diskoPackage
  ];

  # Замыкание сборки для disko: при первом запуске disko строит derivation на live-системе.
  # nativeBuildInputs не попадают в замыкание вывода, поэтому явно кладём в вывод ссылки —
  # тогда gcc/binutils/linux-headers и их зависимости окажутся в store образа.
  diskoBuildClosure = pkgs.runCommand "disko-build-closure" {} ''
    mkdir -p $out
    ln -s ${pkgs.stdenv.cc} $out/cc
    ln -s ${pkgs.binutils} $out/binutils
    ln -s ${pkgs.linuxHeaders} $out/linux-headers
  '';
in
{
  # Автоустановка при загрузке. Диск не задаём в cmdline — выбирается скриптом (NVMe или первый не-removable).
  boot.kernelParams = [
    "nixos.autoInstall=1"
  ];

  # Имя файла ISO на выходе сборки (из config/infrastructure.yaml release-name).
  # В nixpkgs 25.05+ используется image.baseName; из него собирается fileName/isoName.
  image.baseName = lib.mkForce releaseName;

  # Уменьшение размера ISO: более сильное сжатие squashfs
  isoImage.squashfsCompression = "xz -Xdict-size 100%";
  # Опционально: только xz (без dict-size даёт чуть больший размер, но быстрее собирается)
  # isoImage.squashfsCompression = "xz";

  # Кладём в ISO заранее runtime-closure для оффлайн-установки:
  # - disko (включая его зависимости),
  # - edge-node (готовое системное замыкание),
  # - замыкание сборки disko (gcc, binutils, linux-headers),
  # - nix и nixos-install-tools.
  isoImage.storeContents = [
    diskoPackage
    edgeNodeToplevel
    diskoBuildClosure
    pkgs.nix
    pkgs.nixos-install-tools
  ];

  # Кладём флейк в корень ISO (на live-системе может быть /iso/nixos-config или /run/iso/nixos-config)
  isoImage.contents = [
    { source = flakeSrc; target = "/nixos-config"; }
  ];

  # Путь к nixpkgs в store — в образе при сборке (офлайн: disko не качает)
  environment.etc."nixpkgs-path".source = pkgs.writeText "nixpkgs-path" "${pkgs.path}";

  # Замыкание edge-node в store образа — nixos-install не качает из кэша (офлайн)
  environment.etc."edge-node-toplevel".source = edgeNodeToplevel;

  # disko, nix и nixos-install-tools в образе (для скрипта автоустановки)
  environment.systemPackages = [ pkgs.nix pkgs.nixos-install-tools diskoPackage ];

  # Сервис: при загрузке с nixos.autoInstall=1 запускает установку.
  # Вывод — в журнал и на консоль (StandardOutput=journal+console).
  systemd.services.nixos-auto-install = {
    description = "NixOS auto-install to disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
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
      get_disk_from_cmdline() {
        for param in $(cat /proc/cmdline); do
          case "$param" in
            nixos.installDisk=*)
              echo "''${param#nixos.installDisk=}"
              return
              ;;
          esac
        done
      }
      # Выбор диска: 1) из cmdline nixos.installDisk= 2) первый NVMe 3) первый не-removable (RM=0).
      # Не ставим на флешку: если только removable — не используем fallback, выходим с ошибкой.
      detect_install_disk() {
        local from_cmdline
        from_cmdline="$(get_disk_from_cmdline)"
        if [[ -n "$from_cmdline" && -b "$from_cmdline" ]]; then
          echo "$from_cmdline"
          return
        fi
        local dev
        for dev in /dev/nvme*n1; do
          [[ -b "$dev" ]] && echo "$dev" && return
        done
        for dev in $(lsblk -d -n -o NAME,RM 2>/dev/null | awk '$2==0 {print $1}'); do
          [[ -n "$dev" && -b "/dev/$dev" ]] && echo "/dev/$dev" && return
        done
        echo ""
      }

      AUTO="$(get_cmdline)"
      DISK="$(detect_install_disk)"

      [[ "$AUTO" != "1" && "$AUTO" != "true" ]] && exit 0

      if [[ -z "$DISK" || ! -b "$DISK" ]]; then
        echo "ERROR: No suitable install disk (no NVMe, no non-removable disk). Add in GRUB: nixos.installDisk=/dev/nvme0n1 or nixos.installDisk=/dev/sda"
        exit 1
      fi
      echo "=== NixOS auto-install: target disk=$DISK (NVMe preferred, then non-removable) ==="
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

      # NIX_PATH для disko (путь в образе, офлайн)
      [[ -f /etc/nixpkgs-path ]] && export NIX_PATH="nixpkgs=$(cat /etc/nixpkgs-path):''${NIX_PATH:-}"

      # disko — бинарь из образа, без nix run (всё уже в store)
      echo ">>> Running disko (destroy+format+mount)..."
      disko --mode destroy,format,mount --yes-wipe-all-disks "$DISKO_CONFIG"

      echo ">>> Copying flake to /mnt/etc/nixos..."
      mkdir -p /mnt/etc
      cp -r "$CONFIG_DIR" /mnt/etc/nixos

      # Предсобранный toplevel (root/boot по LABEL — подходит для любого диска).
      TOPLEVEL="$(readlink -f /etc/edge-node-toplevel)"
      echo ">>> Running nixos-install (system=$TOPLEVEL)..."
      nixos-install --system "$TOPLEVEL" --no-root-passwd

      # GRUB ставим на выбранный диск; для UEFI нужны модули x86_64-efi (--directory).
      GRUB_INSTALL="$(find "$TOPLEVEL" -path '*/bin/grub-install' -type f 2>/dev/null | head -1)"
      GRUB_EFI_DIR="$(find "$TOPLEVEL" -path '*/lib/grub/x86_64-efi/modinfo.sh' 2>/dev/null | head -1 | xargs dirname)"
      if [[ -n "$GRUB_INSTALL" && -n "$GRUB_EFI_DIR" ]]; then
        echo ">>> Installing GRUB to $DISK..."
        "$GRUB_INSTALL" --boot-directory=/mnt/boot --efi-directory=/mnt/boot --directory="$GRUB_EFI_DIR" "$DISK"
      fi

      echo ">>> Done. Rebooting in 5s..."
      sleep 5
      reboot
    '';
  };
}
