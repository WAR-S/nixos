# Модуль для самоустанавливающегося ISO.
# По умолчанию при загрузке автоматически запускается установка на указанный диск.
# Чтобы загрузиться без установки — в GRUB (e) убери из строки linux: nixos.autoInstall=1 и nixos.installDisk=...
# ISO рассчитан на офлайн: disko и замыкание edge-node кладём в образ при сборке.
{ config, pkgs, flakeSrc, diskoPackage, edgeNodeToplevel, infra, ... }:

let
  defaultInstallDisk = "/dev/sda";
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
  # Параметры ядра по умолчанию: автоустановка при загрузке без правки GRUB
  boot.kernelParams = [
    "nixos.autoInstall=1"
    "nixos.installDisk=${defaultInstallDisk}"
  ];

  # Имя файла ISO на выходе сборки (из config/infrastructure.yaml release-name)
  isoImage.isoName = "${releaseName}.iso";

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

      # NIX_PATH для disko (путь в образе, офлайн)
      [[ -f /etc/nixpkgs-path ]] && export NIX_PATH="nixpkgs=$(cat /etc/nixpkgs-path):''${NIX_PATH:-}"

      # disko — бинарь из образа, без nix run (всё уже в store)
      echo ">>> Running disko (destroy+format+mount)..."
      disko --mode destroy,format,mount --yes-wipe-all-disks "$DISKO_CONFIG"

      echo ">>> Copying flake to /mnt/etc/nixos..."
      mkdir -p /mnt/etc
      cp -r "$CONFIG_DIR" /mnt/etc/nixos

      # Использовать предсобранный toplevel из образа — без переоценки флейка и без загрузок из кэша.
      TOPLEVEL="$(readlink -f /etc/edge-node-toplevel)"
      echo ">>> Running nixos-install (system=$TOPLEVEL)..."
      nixos-install --system "$TOPLEVEL" --no-root-passwd

      echo ">>> Done. Rebooting in 5s..."
      sleep 5
      reboot
    '';
  };
}
