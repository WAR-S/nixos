#!/usr/bin/env bash
# Запускать с live, после: sudo mount /dev/nvme0n1p3 /mnt && sudo mount /dev/nvme0n1p2 /mnt/boot
# Проверка initrd и параметров загрузки установленной системы.

set -e
MNTT=${1:-/mnt}

echo "=== 1. Содержимое toplevel (ядро + initrd) ==="
TOPLEVEL=$(find "$MNTT/nix/store" -maxdepth 1 -type d -name "*nixos-system-edge-node*" 2>/dev/null | head -1)
[[ -z "$TOPLEVEL" ]] && { echo "toplevel не найден"; exit 1; }
echo "Toplevel: $TOPLEVEL"
ls -la "$TOPLEVEL/"
echo ""

echo "=== 2. Файлы initrd (любое имя) ==="
find "$MNTT/nix/store" -path "*nixos-system*" \( -name "initrd" -o -name "initrd*" \) 2>/dev/null
echo ""

echo "=== 3. GRUB: где конфиг и что в нём (linux / initrd / root) ==="
for f in "$MNTT/boot/grub/grub.cfg" "$MNTT/boot/grub/grub.cfg.bak"; do
  [[ -f "$f" ]] && echo "--- $f ---" && cat "$f" | head -120
done
for d in "$MNTT/boot/loader/entries" "$MNTT/boot/EFI" "$MNTT/boot/EFI/BOOT"; do
  [[ -d "$d" ]] && echo "--- entries in $d ---" && ls -la "$d" && for e in "$d"/*; do [[ -f "$e" ]] && echo "--- $e ---" && cat "$e"; done
done
echo ""

echo "=== 4. Параметр root в ядре (из toplevel kernel params) ==="
# NixOS часто пишет kernelParams в toplevel
grep -r "root=" "$TOPLEVEL" 2>/dev/null || true
echo ""

echo "=== 5. Модули в initrd (если есть lsinitrd) ==="
INITRD="$TOPLEVEL/initrd"
[[ -f "$INITRD" ]] && ( command -v lsinitrd >/dev/null && lsinitrd "$INITRD" | head -80 || echo "lsinitrd нет, initrd есть: $INITRD" ) || echo "initrd не найден в toplevel"
