# Точка входа для CLI: устройство из DISKO_DEVICE.
# Пример: sudo DISKO_DEVICE=/dev/nvme0n1 nix run .#disko -- --mode disko ./layers/os/disko.nix
import ./disko-layout.nix { device = builtins.getEnv "DISKO_DEVICE"; }
