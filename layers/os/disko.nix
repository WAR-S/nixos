# Точка входа для CLI: устройство из DISKO_DEVICE. Формат для disko CLI — обёртка в disko.devices.
# Пример: sudo DISKO_DEVICE=/dev/nvme0n1 nix run .#disko -- --mode disko ./layers/os/disko.nix
{ disko.devices = import ./disko-layout.nix { device = builtins.getEnv "DISKO_DEVICE"; }; }
