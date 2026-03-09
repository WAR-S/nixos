{ ... }:

{
  imports = [
    ./00-udev
    ./01-ntp
    ./02-journald
    ./03-hostname
    ./04-ssh
    ./banner
  ];
}