# Чеклист на live-системе (автоустановка не сработала)

Выполняй по порядку в консоли загруженного с ISO NixOS.

## 1. Где смонтирован ISO и что внутри

```bash
mount | grep -E 'iso|sr0|cdrom'
ls -la /iso
ls -la /run/iso
ls -la /iso/nixos-config 2>/dev/null || true
ls -la /iso/iso/nixos-config 2>/dev/null || true
```

**Ожидание:** на NixOS live ISO флейк обычно в **`/iso/iso/nixos-config`** (ISO смонтирован в `/iso`, внутри есть каталог `iso`). Запомни путь, где виден `flake.nix`.

---

## 2. Есть ли флейк на образе

```bash
find /iso /run /mnt /cdrom -name "flake.nix" 2>/dev/null
find / -name "disko.nix" -path "*/layers/os/*" 2>/dev/null
```

**Ожидание:** хотя бы один путь к `flake.nix` и один к `layers/os/disko.nix`. Если пусто — конфиг в образ не попал (пересобрать ISO).

---

## 3. Проверка каталога флейка (подставь свой путь)

```bash
CONFIG_DIR="/iso/iso/nixos-config"   # на live ISO флейк чаще всего здесь; иначе /iso/nixos-config, /run/iso/nixos-config
ls -la "$CONFIG_DIR"
ls -la "$CONFIG_DIR/flake.nix"
ls -la "$CONFIG_DIR/layers/os/disko.nix"
cat "$CONFIG_DIR/layers/os/disko.nix" | head -5
```

**Ожидание:** файлы есть, `disko.nix` читается.

---

## 4. Ручной запуск disko (тест)

```bash
export DISKO_DEVICE=/dev/sda
CONFIG_DIR="/iso/nixos-config"   # тот путь, где нашли flake.nix

cd "$CONFIG_DIR"
nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode destroy,format,mount "$CONFIG_DIR/layers/os/disko.nix"
```

- Если ошибка **"config must be an existing file or flake must be set"** — disko не видит конфиг (путь или способ вызова не подходит).
- Если ошибка **"Permission denied"** или по диску — нужен `sudo` или проверка диска (`lsblk`, правильный ли `/dev/sda`).

---

## 5. Ручная установка (если флейк есть)

```bash
export DISKO_DEVICE=/dev/sda
CONFIG_DIR="/iso/nixos-config"   # или путь из п.1–2

cd "$CONFIG_DIR"
nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode destroy,format,mount "$CONFIG_DIR/layers/os/disko.nix"

mkdir -p /mnt/etc
cp -r "$CONFIG_DIR" /mnt/etc/nixos

nixos-install --flake /mnt/etc/nixos#edge-node --no-root-passwd
reboot
```

После перезагрузки в Proxmox убери загрузку с ISO или поставь диск первым в Boot order.

---

## 6. Если флейка на образе нет

Установка только с сети или с флешки:

```bash
# Вариант A: клон с git
git clone https://github.com/TVOI_USER/nixos-nettop.git /tmp/nixos-config
CONFIG_DIR=/tmp/nixos-config

# Вариант B: флешка смонтирована в /mnt/usb
cp -r /mnt/usb/nixos-nettop /tmp/nixos-config
CONFIG_DIR=/tmp/nixos-config

export DISKO_DEVICE=/dev/sda
cd "$CONFIG_DIR"
nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode destroy,format,mount "$CONFIG_DIR/layers/os/disko.nix"
mkdir -p /mnt/etc && cp -r "$CONFIG_DIR" /mnt/etc/nixos
nixos-install --flake /mnt/etc/nixos#edge-node --no-root-passwd
reboot
```

---

## Краткая сводка

| Проверка              | Команда / что смотреть                          |
|-----------------------|--------------------------------------------------|
| Монтирование ISO      | `mount \| grep iso`; `ls /iso /run/iso`         |
| Наличие флейка        | `find /iso /run -name flake.nix`                |
| Путь к конфигу disko  | `find / -path '*/layers/os/disko.nix'`          |
| Ручной тест disko     | `cd $CONFIG_DIR && nix run .#disko -- ...`       |
| Ручная установка      | disko → cp в /mnt/etc/nixos → nixos-install     |

Результаты п.1–4 можно прислать — по ним можно точнее сказать, почему автоустановка падает.
