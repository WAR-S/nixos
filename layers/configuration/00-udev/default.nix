{ ... }:

{
  # Локальные правила переименования сетевых интерфейсов.
  # Используем штатный механизм NixOS — services.udev.extraRules,
  # он сам положит правила в подходящий файл в /etc/udev/rules.d/.
  services.udev.extraRules = ''
SUBSYSTEM=="net", ACTION=="add", KERNEL=="w*", GOTO="wifi_ap"
SUBSYSTEM=="net", SUBSYSTEMS=="usb", GOTO="handle_usb_modem"
SUBSYSTEM=="net", SUBSYSTEMS=="pci", GOTO="handle_pci"

GOTO="end"

#usb naming
LABEL="handle_usb_modem"
NAME="usbmodem0"
GOTO="end"

#pci
LABEL="handle_pci"
NAME="eth0"
GOTO="end"

#ap
LABEL="wifi_ap"
NAME="wlp2s0"
GOTO="end"

LABEL="end"
'';
}

