# Динамическая разметка диска (disko)

Разметка задаётся в `layers/os/disko-layout.nix`. Устройство диска берётся:
- **при деплое** — из `config/infrastructure.yaml` → `os.diskDevice` (для `nixos-rebuild switch` fileSystems подставляются автоматически);
- **при ручном запуске CLI** — из переменной окружения `DISKO_DEVICE`.

## Что создаётся

- **GPT** таблица разделов
- **ESP** (~512 MiB) — `/boot` (vfat), для systemd-boot/EFI
- **root** (остальное место) — `/` (ext4), метка `nixos` (совместимо с `boot.nix`)

## Как использовать

### 1. Узнать устройство диска

На целевой машине:

```bash
lsblk
# или
ls -la /dev/disk/by-id/
```

Например: `/dev/nvme0n1`, `/dev/sda`, `/dev/disk/by-id/nvme-Samsung_SSD_...`.

### 2. Разметить диск (все данные на нём будут уничтожены)

С хоста с Nix (или с установленного NixOS на самой железке):

```bash
# Обязательно задайте диск
export DISKO_DEVICE=/dev/nvme0n1   # подставьте свой диск

# Разметить и смонтировать в /mnt (для последующей установки)
sudo nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode disko ./layers/os/disko.nix
```

После этого разделы смонтированы в `/mnt` и `/mnt/boot`.

### 3. Полное пересоздание диска (zap + create + mount)

Если нужно гарантированно переразметить диск с нуля (стирает таблицу разделов и данные):

```bash
export DISKO_DEVICE=/dev/nvme0n1
sudo nix --extra-experimental-features "nix-command flakes" run .#disko -- --mode zap_create_empty ./layers/os/disko.nix
```

### 4. Установка/обновление NixOS

После разметки и монтирования в `/mnt`:

```bash
sudo nixos-install --flake .#edge-node
```

При обычном обновлении с host1 на host2 разметка уже учтена в конфиге: в `infrastructure.yaml` задаётся `os.diskDevice` (например `/dev/sda` или `/dev/nvme0n1`), модуль disko подставляет соответствующие `fileSystems` при каждом `nixos-rebuild switch`. Отдельно запускать disko при обновлении не нужно.

**Первый раз** на новой машине диск нужно один раз разметить (на целевом хосте или через SSH), затем ставить/обновлять систему.

## Режимы disko

| Режим | Назначение |
|-------|------------|
| `disko` | Применить разметку по конфигу, смонтировать в /mnt |
| `zap_create_empty` | Очистить диск, создать разделы, смонтировать (для чистой установки) |
| `mount` | Только смонтировать существующие разделы в /mnt |
| `umount` | Размонтировать /mnt |

Подробнее: [nix-community/disko](https://github.com/nix-community/disko).
